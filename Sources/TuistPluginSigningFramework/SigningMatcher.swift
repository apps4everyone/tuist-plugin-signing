import Foundation
import Path

typealias Fingerprint = String
typealias TargetName = String
typealias ConfigurationName = String

protocol SigningMatching {
    func match(from path: AbsolutePath) async throws -> (
        certificates: [Fingerprint: Certificate],
        provisioningProfiles: [TargetName: [ConfigurationName: ProvisioningProfile]]
    )
}

final class SigningMatcher: SigningMatching {
    private let signingFilesLocator: SigningFilesLocating
    private let provisioningProfileParser: ProvisioningProfileParsing
    private let certificateParser: CertificateParsing

    init(
        signingFilesLocator: SigningFilesLocating = SigningFilesLocator(),
        provisioningProfileParser: ProvisioningProfileParsing = ProvisioningProfileParser(),
        certificateParser: CertificateParsing = CertificateParser()
    ) {
        self.signingFilesLocator = signingFilesLocator
        self.provisioningProfileParser = provisioningProfileParser
        self.certificateParser = certificateParser
    }

    func match(from path: AbsolutePath) async throws -> (
        certificates: [Fingerprint: Certificate],
        provisioningProfiles: [TargetName: [ConfigurationName: ProvisioningProfile]]
    ) {
        let certificateFiles = try await self.signingFilesLocator.locateUnencryptedCertificates(from: path)
            .sorted()
        
        let privateKeyFiles = try await self.signingFilesLocator.locateUnencryptedPrivateKeys(from: path)
            .sorted()
        
        let certificates: [Fingerprint: Certificate] = try zip(certificateFiles, privateKeyFiles)
            .map(self.certificateParser.parse)
            .reduce(into: [:]) { dict, certificate in
                dict[certificate.fingerprint] = certificate
            }

        let provisioningProfiles: [TargetName: [ConfigurationName: ProvisioningProfile]] = try await self.signingFilesLocator
            .locateProvisioningProfiles(from: path)
            .map(self.provisioningProfileParser.parse)
            .reduce(into: [:]) { dict, provisioningProfile in
                var currentTargetDict = dict[provisioningProfile.targetName] ?? [:]
                currentTargetDict[provisioningProfile.configurationName] = provisioningProfile
                dict[provisioningProfile.targetName] = currentTargetDict
            }

        return (certificates: certificates, provisioningProfiles: provisioningProfiles)
    }
}
