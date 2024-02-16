import Foundation
import TSCBasic
import TuistPluginSigningFramework

final class EncryptService {
    private let signingCipher: SigningCiphering

    init(signingCipher: SigningCiphering = SigningCipher()) {
        self.signingCipher = signingCipher
    }

    func run(path: String?) throws {
        logger.info("EncryptService.run()")
        let path = try AbsolutePath.path(path)
        try self.signingCipher.encryptSigning(at: path, keepFiles: false)
    }
}
