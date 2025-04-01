import Foundation
import TuistSupport
import Path

protocol SigningInstalling {
    func installProvisioningProfile(
        _ provisioningProfile: ProvisioningProfile
    ) throws
    func installCertificate(
        _ certificate: Certificate,
        keychainPath: AbsolutePath
    ) throws
}

final class SigningInstaller: SigningInstalling {
    private let securityController: SecurityControlling
    private let fileManager: FileManager
    
    init(
        securityController: SecurityControlling = SecurityController(),
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.securityController = securityController
    }

    func installProvisioningProfile(
        _ provisioningProfile: ProvisioningProfile
    ) throws {
        let provisioningProfilesPath = FileHandler.shared.homeDirectory
            .appending(try Path.RelativePath(
                validating: "Library/Developer/Xcode/UserData/Provisioning Profiles")
            )
        
        if !doesFileExists(provisioningProfilesPath.pathString) {
            try FileHandler.shared.createFolder(provisioningProfilesPath)
        }
        
        let provisioningProfileSourcePath = Path.AbsolutePath(stringLiteral: provisioningProfile.path.pathString)
        
        guard let profileExtension = provisioningProfileSourcePath.extension else {
            throw "ProvisioningProfileSource without extension"
        }

        let provisioningProfilePath = provisioningProfilesPath
            .appending(component: provisioningProfile.uuid + "." + profileExtension)
        
        if doesFileExists(provisioningProfilePath.pathString) {
            try fileManager.removeItem(atPath: provisioningProfilePath.pathString)
        }
        
        try FileHandler.shared.copy(
            from: provisioningProfileSourcePath,
            to: provisioningProfilePath
        )
    }
    
    func doesFileExists(_ file: String) -> Bool {
        fileManager.fileExists(atPath: file)
    }

    func installCertificate(
        _ certificate: Certificate,
        keychainPath: AbsolutePath
    ) throws {
        try self.securityController.importCertificate(
            certificate,
            keychainPath: keychainPath
        )
    }
}
