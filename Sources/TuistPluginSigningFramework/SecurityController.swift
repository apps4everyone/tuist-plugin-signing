import Path
import TuistSupport

protocol SecurityControlling {
    func decodeFile(
        at path: AbsolutePath
    ) throws -> String
    func importCertificate(
        _ certificate: Certificate,
        keychainPath: AbsolutePath,
        password: String
    ) throws
    func createKeychain(
        at path: AbsolutePath,
        password: String
    ) throws
    func unlockKeychain(
        at path: AbsolutePath,
        password: String
    ) throws
    func lockKeychain(
        at path: AbsolutePath,
        password: String
    ) throws
}

final class SecurityController: SecurityControlling {
    func decodeFile(
        at path: AbsolutePath
    ) throws -> String {
        try System.shared.capture(["/usr/bin/security", "cms", "-D", "-i", path.pathString])
    }

    func importCertificate(
        _ certificate: Certificate,
        keychainPath: AbsolutePath,
        password: String
    ) throws {
        try? self.importToKeychain(
            at: certificate.publicKey,
            keychainPath: keychainPath,
            password: password
        )
        try? self.importToKeychain(
            at: certificate.privateKey,
            keychainPath: keychainPath,
            password: password
        )
    }

    func createKeychain(
        at path: AbsolutePath,
        password: String
    ) throws {
        try System.shared.run(
            ["/usr/bin/security", "create-keychain", "-p", password, path.pathString]
        )
    }

    func unlockKeychain(
        at path: AbsolutePath,
        password: String
    ) throws {
        try System.shared.run(
            ["/usr/bin/security", "unlock-keychain", "-p", password, path.pathString]
        )
    }

    func lockKeychain(
        at path: AbsolutePath,
        password: String
    ) throws {
        try System.shared.run(
            ["/usr/bin/security", "lock-keychain", "-p", password, path.pathString]
        )
    }

    // MARK: - Helpers

    private func certificateExists(
        _ certificate: Certificate,
        keychainPath: AbsolutePath
    ) throws -> Bool {
        do {
            let existingCertificates = try System.shared.capture([
                "/usr/bin/security",
                "find-certificate",
                "-c",
                certificate.name,
                "-a",
                keychainPath.pathString,
            ])
            return !existingCertificates.isEmpty
        } catch {
            return false
        }
    }

    private func importToKeychain(
        at path: AbsolutePath,
        keychainPath: AbsolutePath,
        password: String
    ) throws {
        try System.shared.run([
            "/usr/bin/security",
            "import", path.pathString,
            "-P", password,
            "-T", "/usr/bin/codesign",
            "-T", "/usr/bin/security",
            "-k", keychainPath.pathString,
        ])
    }
}
