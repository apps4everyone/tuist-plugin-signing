import Path
import TuistSupport
import TuistCore
import PathKit
import Foundation

protocol SigningFilesLocating {
    func locateSigningDirectory(from path: AbsolutePath) async throws -> AbsolutePath?
    func locateProvisioningProfiles(from path: AbsolutePath) async throws -> [AbsolutePath]
    func locateUnencryptedCertificates(from path: AbsolutePath) async throws -> [AbsolutePath]
    func locateEncryptedCertificates(from path: AbsolutePath) async throws -> [AbsolutePath]
    func locateUnencryptedPrivateKeys(from path: AbsolutePath) async throws -> [AbsolutePath]
    func locateEncryptedPrivateKeys(from path: AbsolutePath) async throws -> [AbsolutePath]
}

final class SigningFilesLocator: SigningFilesLocating {
    private let rootDirectoryLocator: RootDirectoryLocating
    private let fileManager: FileManager
    
    init(rootDirectoryLocator: RootDirectoryLocating = RootDirectoryLocator(), fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.rootDirectoryLocator = rootDirectoryLocator
    }

    func locateSigningDirectory(from path: AbsolutePath) async throws -> AbsolutePath? {
        guard let rootDirectory = try await self.rootDirectoryLocator.locate(from: path)
        else {
            throw "No SigningDirectory found"
        }
        let signingDirectory = rootDirectory.appending(components: Constants.tuistDirectoryName, Constants.signingDirectoryName)
        return fileManager.fileExists(atPath: signingDirectory.pathString) ? signingDirectory : nil
    }

    func locateProvisioningProfiles(from path: AbsolutePath) async throws -> [AbsolutePath] {
        try await locateSigningFiles(at: path)
            .filter { $0.extension == "mobileprovision" || $0.extension == "provisionprofile" }
    }

    func locateUnencryptedCertificates(from path: AbsolutePath) async throws -> [AbsolutePath] {
        try await locateSigningFiles(at: path)
            .filter { $0.extension == "cer" }
    }

    func locateEncryptedCertificates(from path: AbsolutePath) async throws -> [AbsolutePath] {
        try await locateSigningFiles(at: path)
            .filter { $0.pathString.hasSuffix("cer.encrypted") }
    }

    func locateUnencryptedPrivateKeys(from path: AbsolutePath) async throws -> [AbsolutePath] {
        try await locateSigningFiles(at: path)
            .filter { $0.extension == "p12" }
    }

    func locateEncryptedPrivateKeys(from path: AbsolutePath) async throws -> [AbsolutePath] {
        try await locateSigningFiles(at: path)
            .filter { $0.pathString.hasSuffix("p12.encrypted") }
    }

    // MARK: - Helpers

    private func locateSigningFiles(at path: AbsolutePath) async throws -> [AbsolutePath] {
        guard let rootDirectory = try await self.rootDirectoryLocator.locate(from: path)
        else {
            return []
        }
        let signingDirectory = rootDirectory.appending(components: Constants.tuistDirectoryName, Constants.signingDirectoryName)
        return PathKit
            .Path(signingDirectory.pathString)
            .glob("*")
            .compactMap { try? AbsolutePath(validating: $0.string) }
    }
}
