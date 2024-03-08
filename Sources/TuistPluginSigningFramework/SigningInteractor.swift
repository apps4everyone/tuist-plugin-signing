import Foundation
import TSCBasic
import TuistSupport
import TuistCore
import TuistGraph
import ProjectAutomation

/// Interacts with signing
public protocol SigningInteracting {
    /// Install signing for a given graph
    func install(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) throws -> [LintingIssue]
    
    /// Exports the provisioning profiles infos JSON
    func export(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) throws -> [LintingIssue]
}

public final class SigningInteractor: SigningInteracting {
    private let signingFilesLocator: SigningFilesLocating
    private let rootDirectoryLocator: RootDirectoryLocating
    private let signingMatcher: SigningMatching
    private let signingInstaller: SigningInstalling
    private let signingLinter: SigningLinting
    private let securityController: SecurityControlling
    private let signingCipher: SigningCiphering

    public convenience init() {
        self.init(
            signingFilesLocator: SigningFilesLocator(),
            rootDirectoryLocator: RootDirectoryLocator(),
            signingMatcher: SigningMatcher(),
            signingInstaller: SigningInstaller(),
            signingLinter: SigningLinter(),
            securityController: SecurityController(),
            signingCipher: SigningCipher()
        )
    }

    init(
        signingFilesLocator: SigningFilesLocating,
        rootDirectoryLocator: RootDirectoryLocating,
        signingMatcher: SigningMatching,
        signingInstaller: SigningInstalling,
        signingLinter: SigningLinting,
        securityController: SecurityControlling,
        signingCipher: SigningCiphering
    ) {
        self.signingFilesLocator = signingFilesLocator
        self.rootDirectoryLocator = rootDirectoryLocator
        self.signingMatcher = signingMatcher
        self.signingInstaller = signingInstaller
        self.signingLinter = signingLinter
        self.securityController = securityController
        self.signingCipher = signingCipher
    }

    public func install(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) throws -> [LintingIssue] {
        guard let signingDirectory = try self.signingFilesLocator.locateSigningDirectory(from: path),
              let derivedDirectory = self.rootDirectoryLocator.locate(from: path)?
              .appending(component: Constants.DerivedDirectory.name)
        else { return [] }

        let keychainPath = derivedDirectory.appending(component: Constants.DerivedDirectory.signingKeychain)

        let masterKey = try self.signingCipher.readMasterKey(at: signingDirectory)
        
        try FileHandler.shared.createFolder(derivedDirectory)

        if !FileHandler.shared.exists(keychainPath) {
            try self.securityController.createKeychain(at: keychainPath, password: masterKey)
        }
        
        try self.securityController.unlockKeychain(at: keychainPath, password: masterKey)
        
        defer { try? self.securityController.lockKeychain(at: keychainPath, password: masterKey) }

        try self.signingCipher.decryptSigning(at: path, keepFiles: true)
        
        defer { try? self.signingCipher.encryptSigning(at: path, keepFiles: false) }

        let (certificates, provisioningProfiles) = try self.signingMatcher.match(from: path)

        let targets: [ProjectAutomation.Target] = graph.projects.flatMap { (_, value) in
            value.targets
        }

        return try targets.flatMap { target in
            try self.install(
                target: target,
                keychainPath: keychainPath,
                certificates: certificates,
                provisioningProfiles: provisioningProfiles
            )
        }
    }

    public func export(
        path: AbsolutePath,
        graph: ProjectAutomation.Graph
    ) throws -> [LintingIssue] {
        guard let signingDirectory = try self.signingFilesLocator.locateSigningDirectory(from: path),
              let derivedDirectory = self.rootDirectoryLocator.locate(from: path)?
              .appending(component: Constants.DerivedDirectory.name)
        else { return [] }

        let keychainPath = derivedDirectory.appending(component: Constants.DerivedDirectory.signingKeychain)

        let masterKey = try signingCipher.readMasterKey(at: signingDirectory)
        
        try FileHandler.shared.createFolder(derivedDirectory)

        if !FileHandler.shared.exists(keychainPath) {
            try self.securityController.createKeychain(at: keychainPath, password: masterKey)
        }
        
        try self.securityController.unlockKeychain(at: keychainPath, password: masterKey)
        
        defer { try? self.securityController.lockKeychain(at: keychainPath, password: masterKey) }

        try self.signingCipher.decryptSigning(at: path, keepFiles: true)
        
        defer { try? self.signingCipher.encryptSigning(at: path, keepFiles: false) }

        let (_, provisioningProfiles) = try self.signingMatcher.match(from: path)
        
        try self.export(
            to: derivedDirectory.appending(component: "ProvisioningProfiles.json"),
            provisioningProfiles: provisioningProfiles
        )
        
        return []
    }

    // MARK: - Helpers

    private func install(
        target: ProjectAutomation.Target,
        keychainPath: AbsolutePath,
        certificates: [Fingerprint: Certificate],
        provisioningProfiles: [TargetName: [ConfigurationName: ProvisioningProfile]]
    ) throws -> [LintingIssue] {
        let configurationNames: Set<String> = Set(target.settings.configurations.map { $0.key.name } )

        let signingPairs = configurationNames.compactMap { configurationName -> (certificate: Certificate, provisioningProfile: ProvisioningProfile)? in
            guard let provisioningProfile = provisioningProfiles[target.name]?[configurationName],
                  let certificate = certificates.first(for: provisioningProfile)
            else {
                return nil
            }
            return (certificate: certificate, provisioningProfile: provisioningProfile)
        }

        for signingPair in signingPairs.map(\.certificate) {
            try self.signingInstaller.installCertificate(signingPair, keychainPath: keychainPath)
        }

        let provisioningProfileInstallLintIssues = try signingPairs.map(\.provisioningProfile)
            .flatMap(self.signingInstaller.installProvisioningProfile)
        
        try provisioningProfileInstallLintIssues.printAndThrowErrorsIfNeeded()

        let provisioningProfileLintIssues = signingPairs.map(\.provisioningProfile).flatMap {
            self.signingLinter.lint(provisioningProfile: $0, target: target)
        }
        
        try provisioningProfileLintIssues.printAndThrowErrorsIfNeeded()

        let signingPairLintIssues = signingPairs.flatMap(self.signingLinter.lint)
        
        try signingPairLintIssues.printAndThrowErrorsIfNeeded()

        let certificateLintIssues = signingPairs.map(\.certificate).flatMap(self.signingLinter.lint)
        
        try certificateLintIssues.printAndThrowErrorsIfNeeded()

        return [
            provisioningProfileInstallLintIssues,
            provisioningProfileLintIssues,
            signingPairLintIssues,
            certificateLintIssues,
        ].flatMap { $0 }
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
}
