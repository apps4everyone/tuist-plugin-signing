import CryptoSwift
import Foundation
import Path
import TuistSupport
import TuistCore

enum SigningCipherError: FatalError, Equatable {
    case failedToEncrypt
    case failedToDecrypt(String)
    case ivGenerationFailed(String)
    case masterKeyNotFound(AbsolutePath)
    case signingDirectoryNotFound(AbsolutePath)

    var type: ErrorType {
        switch self {
        case .failedToEncrypt, .failedToDecrypt, .ivGenerationFailed,
             .masterKeyNotFound, .signingDirectoryNotFound:
            return .abort
        }
    }

    var description: String {
        switch self {
        case .failedToEncrypt:
            return "Unable to encrypt data"
        case let .failedToDecrypt(reason):
            return "Could not decrypt data: \(reason)"
        case let .ivGenerationFailed(reason):
            return "Generation of IV failed with error: \(reason)"
        case let .masterKeyNotFound(masterKeyPath):
            return "Could not find master.key at \(masterKeyPath.pathString)"
        case let .signingDirectoryNotFound(fromPath):
            return "Could not find signing directory from \(fromPath.pathString)"
        }
    }
}

public protocol SigningCiphering {
    func encryptSigning(at path: AbsolutePath, keepFiles: Bool) async throws
    func decryptSigning(at path: AbsolutePath, keepFiles: Bool) async throws
    func readMasterKey(at path: AbsolutePath) async throws -> String
}

public final class SigningCipher: SigningCiphering {
    private let rootDirectoryLocator: RootDirectoryLocating
    private let signingFilesLocator: SigningFilesLocating
    private let fileManager: FileManager

    public convenience init() {
        self.init(
            rootDirectoryLocator: RootDirectoryLocator(),
            signingFilesLocator: SigningFilesLocator(),
            fileManager: .default
        )
    }

    init(
        rootDirectoryLocator: RootDirectoryLocating,
        signingFilesLocator: SigningFilesLocating,
        fileManager: FileManager
    ) {
        self.fileManager = fileManager
        self.rootDirectoryLocator = rootDirectoryLocator
        self.signingFilesLocator = signingFilesLocator
    }

    public func encryptSigning(at path: AbsolutePath, keepFiles: Bool) async throws {
        let masterKey = try await masterKey(at: path)
        let signingKeyFiles = try await locateUnencryptedSigningFiles(at: path)
        guard !signingKeyFiles.isEmpty else {
            throw "signingKeyFiles.isEmpty"
        }

        let correctlyEncryptedSigningFiles = try await correctlyEncryptedSigningFiles(at: path, masterKey: masterKey)

        try await locateEncryptedSigningFiles(at: path)
            .filter { !correctlyEncryptedSigningFiles.map(\.encrypted).contains($0) }
            .map { $0.pathString }
            .forEach(fileManager.removeItem(atPath:))

        let cipheredKeys = try signingKeyFiles
            .filter { !correctlyEncryptedSigningFiles.map(\.unencrypted).contains($0) }
            .map(FileHandler.shared.readFile)
            .map { try encryptData($0, masterKey: masterKey) }

        for (key, file) in zip(cipheredKeys, signingKeyFiles) {
            let encryptedPath = try AbsolutePath(validating: file.pathString + "." + Constants.encryptedExtension)
            try key.write(to: encryptedPath.url)
        }

        if !keepFiles {
            try signingKeyFiles
                .map { $0.pathString }
                .forEach(fileManager.removeItem(atPath:))
        }
    }

    public func decryptSigning(at path: AbsolutePath, keepFiles: Bool) async throws {
        let masterKey = try await masterKey(at: path)
        let signingKeyFiles = try await locateEncryptedSigningFiles(at: path)
        guard !signingKeyFiles.isEmpty else { return }
        let decipheredKeys = try signingKeyFiles
            .map(FileHandler.shared.readFile)
            .map {
                try decryptData($0, masterKey: masterKey)
            }

        try await locateUnencryptedSigningFiles(at: path)
            .map { $0.pathString }
            .forEach(fileManager.removeItem(atPath:))

        for (key, keyFile) in zip(decipheredKeys, signingKeyFiles) {
            let decryptedPath = try AbsolutePath(
                validating: keyFile.parentDirectory.pathString + "/" + keyFile
                    .basenameWithoutExt
            )
            try key.write(to: decryptedPath.url)
        }

        if !keepFiles {
            try signingKeyFiles
                .map { $0.pathString }
                .forEach(fileManager.removeItem(atPath:))
        }
    }

    public func readMasterKey(at path: AbsolutePath) async throws -> String {
        guard let rootDirectory = try await rootDirectoryLocator.locate(from: path)
        else { throw SigningCipherError.signingDirectoryNotFound(path) }
        let masterKeyFile = rootDirectory.appending(components: Constants.tuistDirectoryName, Constants.masterKey)
        guard fileManager.fileExists(atPath: masterKeyFile.pathString) else { throw SigningCipherError.masterKeyNotFound(masterKeyFile) }
        let plainMasterKey = try FileHandler.shared.readTextFile(masterKeyFile).trimmingCharacters(in: .newlines)
        return plainMasterKey
    }

    // MARK: - Helpers

    private func locateUnencryptedSigningFiles(at path: AbsolutePath) async throws -> [AbsolutePath] {
        try await signingFilesLocator.locateUnencryptedCertificates(from: path) + signingFilesLocator
            .locateUnencryptedPrivateKeys(from: path)
    }

    private func locateEncryptedSigningFiles(at path: AbsolutePath) async throws -> [AbsolutePath] {
        try await signingFilesLocator.locateEncryptedCertificates(from: path) + signingFilesLocator
            .locateEncryptedPrivateKeys(from: path)
    }

    private func correctlyEncryptedSigningFiles(
        at path: AbsolutePath,
        masterKey: Data
    ) async throws -> [(unencrypted: AbsolutePath, encrypted: AbsolutePath)] {
        try await locateUnencryptedSigningFiles(at: path).compactMap { unencryptedFile in
            let encryptedFile = try AbsolutePath(validating: unencryptedFile.pathString + "." + Constants.encryptedExtension)
            guard fileManager.fileExists(atPath: encryptedFile.pathString) else { return nil }
            let isEncryptionNeeded: Bool = try self.isEncryptionNeeded(
                encryptedFile: encryptedFile,
                unencryptedFile: unencryptedFile,
                masterKey: masterKey
            )
            return isEncryptionNeeded ? nil : (unencrypted: unencryptedFile, encrypted: encryptedFile)
        }
    }

    private func isEncryptionNeeded(encryptedFile: AbsolutePath, unencryptedFile: AbsolutePath, masterKey: Data) throws -> Bool {
        guard let encodedString = String(data: try FileHandler.shared.readFile(encryptedFile), encoding: .utf8),
              let dividerIndex = encodedString.firstIndex(of: "-"),
              let iv = Data(base64Encoded: String(encodedString.prefix(upTo: dividerIndex)))
        else { throw SigningCipherError.failedToDecrypt("corrupted data") }

        let aesCipher = try AES(key: masterKey.bytes, blockMode: CTR(iv: iv.bytes), padding: .noPadding)
        let unencryptedData = try FileHandler.shared.readFile(unencryptedFile)
        let encryptedBase64String = try aesCipher.encrypt(unencryptedData.bytes).toBase64()
        guard let encryptedBase64String, let data = (iv.base64EncodedString() + "-" + encryptedBase64String).data(using: .utf8) else {
            throw SigningCipherError.failedToEncrypt
        }

        return try FileHandler.shared.readFile(encryptedFile) != data
    }

    private func encryptData(_ data: Data, masterKey: Data) throws -> Data {
        let iv = try generateIv()
        let aesCipher = try AES(key: masterKey.bytes, blockMode: CTR(iv: iv.bytes), padding: .noPadding)
        let encryptedBase64String = try aesCipher.encrypt(data.bytes).toBase64()
        guard let encryptedBase64String, let data = (iv.base64EncodedString() + "-" + encryptedBase64String).data(using: .utf8) else {
            throw SigningCipherError.failedToEncrypt
        }
        return data
    }

    private func decryptData(_ data: Data, masterKey: Data) throws -> Data {
        guard let encodedString = String(data: data, encoding: .utf8),
              let dividerIndex = encodedString.firstIndex(of: "-"),
              let iv = Data(base64Encoded: String(encodedString.prefix(upTo: dividerIndex)))
        else { throw SigningCipherError.failedToDecrypt("corrupted data") }

        let dataToDecrypt = Data(base64Encoded: String(encodedString.suffix(from: dividerIndex).dropFirst()))
        let aesCipher = try AES(key: masterKey.bytes, blockMode: CTR(iv: iv.bytes), padding: .noPadding)
        guard let decryptedData = try dataToDecrypt?.decrypt(cipher: aesCipher)
        else { throw SigningCipherError.failedToDecrypt("data is in wrong format") }
        return decryptedData
    }

    private func masterKey(at path: AbsolutePath) async throws -> Data {
        try await readMasterKey(at: path).data(using: .utf8)!.sha256()
    }

    private func generateIv() throws -> Data {
        let blockSize = 16
        var iv = Data(repeating: 0, count: blockSize)
        let result = try iv.withUnsafeMutableBytes { bytes -> Int32 in
            guard let baseAddress = bytes.baseAddress
            else { throw SigningCipherError.ivGenerationFailed("Base address not found") }
            return SecRandomCopyBytes(kSecRandomDefault, blockSize, baseAddress)
        }
        if result == errSecSuccess {
            return iv
        } else {
            if let errorMessage = SecCopyErrorMessageString(result, nil) {
                throw SigningCipherError.ivGenerationFailed(String(errorMessage))
            } else {
                throw SigningCipherError.ivGenerationFailed("code: \(result)")
            }
        }
    }
}
