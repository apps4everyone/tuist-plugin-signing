import Foundation
import TSCBasic
import TuistPluginSigningFramework

final class DecryptService {
    private let signingCipher: SigningCiphering

    init(signingCipher: SigningCiphering = SigningCipher()) {
        self.signingCipher = signingCipher
    }

    func run(path: String?) throws {
        logger.info("DecryptService.run()")
        let path = try AbsolutePath.path(path)
        try self.signingCipher.decryptSigning(at: path, keepFiles: false)
    }
}
