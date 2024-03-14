import Foundation
import TSCBasic
import TuistSupport
import TuistGraph

struct CodeSigningConstants {
    public static let codeSigningKeychain = "CodeSigning.keychain"
    public static let codeSigningFolder = "CodeSigning"
    public static let codeSigningKeychainPath = "\(Self.codeSigningFolder)/\(Self.codeSigningKeychain)"
    
    public static let provisioningProfilesJson = "ProvisioningProfiles.json"
    public static let provisioningProfilesPath = "\(Self.codeSigningFolder)/\(Self.provisioningProfilesJson)"
    
    public static let certificatesJson = "Certificates.json"
    public static let certificatesPath = "\(Self.codeSigningFolder)/\(Self.certificatesJson)"
}

public class SigningMapper {
    private let signingFilesLocator: SigningFilesLocating
    private let signingMatcher: SigningMatching
    private let signingCipher: SigningCiphering

    public convenience init() {
        self.init(
            signingFilesLocator: SigningFilesLocator(),
            signingMatcher: SigningMatcher(),
            signingCipher: SigningCipher()
        )
    }

    init(
        signingFilesLocator: SigningFilesLocating,
        signingMatcher: SigningMatching,
        signingCipher: SigningCiphering
    ) {
        self.signingFilesLocator = signingFilesLocator
        self.signingMatcher = signingMatcher
        self.signingCipher = signingCipher
    }
}
