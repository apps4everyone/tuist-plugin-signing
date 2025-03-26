import Foundation
import Path
import TuistPluginSigningFramework

final class EncryptService {
    private let signingCipher: SigningCiphering

    init(signingCipher: SigningCiphering = SigningCipher()) {
        self.signingCipher = signingCipher
    }

    func run(path: AbsolutePath) async throws {
        logger.info("EncryptService.run()")
        try await self.signingCipher.encryptSigning(at: path, keepFiles: false)
    }
}
