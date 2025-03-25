import Foundation
import Path
import TuistPluginSigningFramework

final class DecryptService {
    private let signingCipher: SigningCiphering

    init(signingCipher: SigningCiphering = SigningCipher()) {
        self.signingCipher = signingCipher
    }

    func run(path: String?) async throws {
        logger.info("DecryptService.run()")
        let path = try AbsolutePath.path(path)
        try await self.signingCipher.decryptSigning(at: path, keepFiles: false)
    }
}
