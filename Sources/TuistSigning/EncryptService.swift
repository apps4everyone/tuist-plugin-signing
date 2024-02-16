import Foundation
import TSCBasic
import TuistSupport
import TuistSigningLibrary

final class EncryptService {
    private let signingCipher: SigningCiphering

    init(signingCipher: SigningCiphering = SigningCipher()) {
        self.signingCipher = signingCipher
    }

    func run(path: String?) throws {
        logger.info("EncryptService.run()")
        let path = try self.path(path)
        try self.signingCipher.encryptSigning(at: path, keepFiles: false)
    }

    // MARK: - Helpers

    private func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(
                validating: path,
                relativeTo: FileHandler.shared.currentPath
            )
        } else {
            return FileHandler.shared.currentPath
        }
    }
}
