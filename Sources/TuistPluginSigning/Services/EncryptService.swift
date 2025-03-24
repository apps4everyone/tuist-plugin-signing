import Foundation
import Path
import TuistPluginSigningFramework

final class EncryptService {
    private let signingCipher: SigningCiphering

    init(signingCipher: SigningCiphering = SigningCipher()) {
        self.signingCipher = signingCipher
    }

    func run(path: String?) async throws {
        logger.info("EncryptService.run()")
        let path = try AbsolutePath.path(path)
        try await self.signingCipher.encryptSigning(at: path, keepFiles: false)
    }
}
