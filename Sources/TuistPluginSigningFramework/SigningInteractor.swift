import Foundation
import Path
import TuistSupport
import XcodeGraph
import ProjectAutomation
import TuistCore

public protocol SigningInteracting {
    func install(
        path: AbsolutePath
    ) async throws

    func export(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) async throws
}

public final class SigningInteractor: SigningInteracting {
    private let signingFilesLocator: SigningFilesLocating
    private let rootDirectoryLocator: RootDirectoryLocating
    private let signingMatcher: SigningMatching
    private let signingInstaller: SigningInstalling
    private let securityController: SecurityControlling
    private let signingCipher: SigningCiphering
    private let fileManager: FileManager

    public convenience init() {
        self.init(
            signingFilesLocator: SigningFilesLocator(),
            rootDirectoryLocator: RootDirectoryLocator(),
            signingMatcher: SigningMatcher(),
            signingInstaller: SigningInstaller(),
            securityController: SecurityController(),
            signingCipher: SigningCipher(),
            fileManager: .default
        )
    }

    init(
        signingFilesLocator: SigningFilesLocating,
        rootDirectoryLocator: RootDirectoryLocating,
        signingMatcher: SigningMatching,
        signingInstaller: SigningInstalling,
        securityController: SecurityControlling,
        signingCipher: SigningCiphering,
        fileManager: FileManager
    ) {
        self.fileManager = fileManager
        self.signingFilesLocator = signingFilesLocator
        self.rootDirectoryLocator = rootDirectoryLocator
        self.signingMatcher = signingMatcher
        self.signingInstaller = signingInstaller
        self.securityController = securityController
        self.signingCipher = signingCipher
    }

    public func install(
        path: AbsolutePath
    ) async throws {
        guard let signingDirectory = try await self.signingFilesLocator.locateSigningDirectory(from: path),
              let rootDirectory = try await self.rootDirectoryLocator.locate(from: path)
        else {
            throw "No SigningDirectory or RootDirectory found"
        }

        let keychainPath = rootDirectory.appending(
            component: CodeSigningConstants.codeSigningKeychainPath
        )

        let masterKey = try await self.signingCipher.readMasterKey(at: signingDirectory)

        if !fileManager.fileExists(atPath: keychainPath.pathString) {
            try self.securityController.createKeychain(at: keychainPath, password: masterKey)
        }
        
        try self.securityController.unlockKeychain(
            at: keychainPath,
            password: masterKey
        )
        
        defer {
            try? self.securityController.lockKeychain(
                at: keychainPath,
                password: masterKey
            )
        }

        try await self.signingCipher.decryptSigning(at: path, keepFiles: true)
        
        let (certificatesInfos, provisioningProfilesInfos) = try await self.signingMatcher.match(from: path)

        try self.install(
            keychainPath: keychainPath,
            certificatesInfos: certificatesInfos,
            password: masterKey
        )

        try self.install(
            keychainPath: keychainPath,
            provisioningProfilesInfos: provisioningProfilesInfos
        )
        
        try? await self.signingCipher.encryptSigning(at: path, keepFiles: false)
    }

    public func export(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) async throws {
        guard let signingDirectory = try await self.signingFilesLocator.locateSigningDirectory(from: path),
              let rootDirectory = try await self.rootDirectoryLocator.locate(from: path)
        else {
            throw "No SigningDirectory or RootDirectory found"
        }

        let keychainPath = rootDirectory.appending(component: CodeSigningConstants.codeSigningKeychainPath)

        let masterKey = try await signingCipher.readMasterKey(at: signingDirectory)

        if !fileManager.fileExists(atPath: keychainPath.pathString) {
            try self.securityController.createKeychain(at: keychainPath, password: masterKey)
        }
        
        try self.securityController.unlockKeychain(at: keychainPath, password: masterKey)
        
        defer { try? self.securityController.lockKeychain(at: keychainPath, password: masterKey) }

        try await self.signingCipher.decryptSigning(at: path, keepFiles: true)
        
        let (certificatesDict, provisioningProfiles) = try await self.signingMatcher.match(from: path)

        try self.export(
            to: rootDirectory.appending(component: CodeSigningConstants.provisioningProfilesPath),
            provisioningProfiles: provisioningProfiles
        )

        try self.export(
            to: rootDirectory.appending(component: CodeSigningConstants.certificatesPath),
            certificates: certificatesDict.values.map { $0 }
        )
        
        try? await self.signingCipher.encryptSigning(at: path, keepFiles: false)
    }

    // MARK: - Helpers

    private func install(
        keychainPath: AbsolutePath,
        provisioningProfilesInfos: [TargetName: [ConfigurationName: ProvisioningProfile]]
    ) throws {
        var provisioningProfiles = [ProvisioningProfile]()

        for provisioningProfilesInfo in provisioningProfilesInfos.values {
            provisioningProfiles.append(contentsOf: provisioningProfilesInfo.values)
        }

        try Set(provisioningProfiles).forEach { provisioningProfile in
            try self.signingInstaller.installProvisioningProfile(provisioningProfile)
        }
    }

    private func install(
        keychainPath: AbsolutePath,
        certificatesInfos: [Fingerprint: Certificate],
        password: String
    ) throws {
        let certificates: Set<Certificate> = Set(certificatesInfos.values)

        for certificate in certificates {
            try self.signingInstaller.installCertificate(
                certificate,
                keychainPath: keychainPath,
                password: password
            )
        }
    }

    private func export(
        to filePath: AbsolutePath,
        provisioningProfiles: [TargetName: [ConfigurationName: ProvisioningProfile]]
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let jsonData = try encoder.encode(provisioningProfiles)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        try FileHandler.shared.write(jsonString, path: filePath, atomically: true)
    }

    private func export(
        to filePath: AbsolutePath,
        certificates: [Certificate]
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let jsonData = try encoder.encode(certificates)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw "Not a utf8 json string"
        }
        try FileHandler.shared.write(jsonString, path: filePath, atomically: true)
    }
}

extension Certificate: Encodable {
    private enum CodingKeys: String, CodingKey {
        case name, fingerprint, developmentTeam, isRevoked
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.name, forKey: .name)
        try container.encode(self.fingerprint, forKey: .fingerprint)
        try container.encode(self.developmentTeam, forKey: .developmentTeam)
        try container.encode(self.isRevoked, forKey: .isRevoked)
    }
}

extension Certificate: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.fingerprint)
    }
}

extension ProvisioningProfile: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.uuid)
    }
}
