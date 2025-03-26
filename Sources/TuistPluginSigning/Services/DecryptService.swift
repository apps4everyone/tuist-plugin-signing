import Foundation
import Path
import TuistPluginSigningFramework

final class DecryptService {
    private let signingCipher: SigningCiphering

    init(signingCipher: SigningCiphering = SigningCipher()) {
        self.signingCipher = signingCipher
    }

    func run(path: AbsolutePath) async throws {
        logger.info("DecryptService.run()")
        try await self.signingCipher.decryptSigning(at: path, keepFiles: false)
    }
}
