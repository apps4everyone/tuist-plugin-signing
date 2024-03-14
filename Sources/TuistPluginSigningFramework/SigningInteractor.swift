import Foundation
import TSCBasic
import TuistSupport
import TuistGraph
import ProjectAutomation
import TuistCore

public protocol SigningInteracting {
    func install(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) throws

    func export(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) throws
}

public final class SigningInteractor: SigningInteracting {
    private let signingFilesLocator: SigningFilesLocating
    private let rootDirectoryLocator: RootDirectoryLocating
    private let signingMatcher: SigningMatching
    private let signingInstaller: SigningInstalling
    private let securityController: SecurityControlling
    private let signingCipher: SigningCiphering

    public convenience init() {
        self.init(
            signingFilesLocator: SigningFilesLocator(),
            rootDirectoryLocator: RootDirectoryLocator(),
            signingMatcher: SigningMatcher(),
            signingInstaller: SigningInstaller(),
            securityController: SecurityController(),
            signingCipher: SigningCipher()
        )
    }

    init(
        signingFilesLocator: SigningFilesLocating,
        rootDirectoryLocator: RootDirectoryLocating,
        signingMatcher: SigningMatching,
        signingInstaller: SigningInstalling,
        securityController: SecurityControlling,
        signingCipher: SigningCiphering
    ) {
        self.signingFilesLocator = signingFilesLocator
        self.rootDirectoryLocator = rootDirectoryLocator
        self.signingMatcher = signingMatcher
        self.signingInstaller = signingInstaller
        self.securityController = securityController
        self.signingCipher = signingCipher
    }

    public func install(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) throws {
        guard let signingDirectory = try self.signingFilesLocator.locateSigningDirectory(from: path),
              let rootDirectory = self.rootDirectoryLocator.locate(from: path)
        else {
            throw "No SigningDirectory or RootDirectory found"
        }

        let keychainPath = rootDirectory.appending(component: CodeSigningConstants.codeSigningKeychainPath)

        let masterKey = try self.signingCipher.readMasterKey(at: signingDirectory)

        if !FileHandler.shared.exists(keychainPath) {
            try self.securityController.createKeychain(at: keychainPath, password: masterKey)
        }
        
        try self.securityController.unlockKeychain(at: keychainPath, password: masterKey)
        
        defer { try? self.securityController.lockKeychain(at: keychainPath, password: masterKey) }

        try self.signingCipher.decryptSigning(at: path, keepFiles: true)
        
        defer { try? self.signingCipher.encryptSigning(at: path, keepFiles: false) }

        let (certificatesDict, provisioningProfiles) = try self.signingMatcher.match(from: path)

        let targets: [ProjectAutomation.Target] = graph.projects.flatMap { (_, value) in
            value.targets
        }

        try targets.forEach { target in
            try self.install(
                target: target,
                keychainPath: keychainPath,
                certificates: certificatesDict,
                provisioningProfiles: provisioningProfiles
            )
        }
    }

    public func export(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) throws {
        guard let signingDirectory = try self.signingFilesLocator.locateSigningDirectory(from: path),
              let rootDirectory = self.rootDirectoryLocator.locate(from: path)
        else {
            throw "No SigningDirectory or RootDirectory found"
        }

        let keychainPath = rootDirectory.appending(component: CodeSigningConstants.codeSigningKeychainPath)

        let masterKey = try signingCipher.readMasterKey(at: signingDirectory)

        if !FileHandler.shared.exists(keychainPath) {
            try self.securityController.createKeychain(at: keychainPath, password: masterKey)
        }
        
        try self.securityController.unlockKeychain(at: keychainPath, password: masterKey)
        
        defer { try? self.securityController.lockKeychain(at: keychainPath, password: masterKey) }

        try self.signingCipher.decryptSigning(at: path, keepFiles: true)
        
        defer { try? self.signingCipher.encryptSigning(at: path, keepFiles: false) }

        let (certificatesDict, provisioningProfiles) = try self.signingMatcher.match(from: path)

        try self.export(
            to: rootDirectory.appending(component: CodeSigningConstants.provisioningProfilesPath),
            provisioningProfiles: provisioningProfiles
        )

        try self.export(
            to: rootDirectory.appending(component: CodeSigningConstants.certificatesPath),
            certificates: certificatesDict.values.map { $0 }
        )
    }

    // MARK: - Helpers

    private func install(
        target: ProjectAutomation.Target,
        keychainPath: AbsolutePath,
        certificates: [Fingerprint: Certificate],
        provisioningProfiles: [TargetName: [ConfigurationName: ProvisioningProfile]]
    ) throws {
        let configurationNames: Set<String> = Set(target.settings.configurations.map { $0.key.name } )

        let signingPairs = configurationNames.compactMap { configurationName -> (certificate: Certificate, provisioningProfile: ProvisioningProfile)? in
            guard let provisioningProfile = provisioningProfiles[target.name]?[configurationName],
                  let certificate = certificates.first(for: provisioningProfile)
            else {
                return nil
            }
            return (certificate: certificate, provisioningProfile: provisioningProfile)
        }

        let certificates = Set(signingPairs.map(\.certificate))

        for certificate in certificates {
            try self.signingInstaller.installCertificate(certificate, keychainPath: keychainPath)
        }

        let provisioningProfiles = Set(signingPairs.map(\.provisioningProfile))

        try provisioningProfiles.forEach { provisioningProfile in
            try self.signingInstaller.installProvisioningProfile(provisioningProfile)
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
