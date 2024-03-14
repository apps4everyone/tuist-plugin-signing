import Foundation
import TSCBasic
import TuistSupport

private protocol Entitlements: Decodable {
    var appId: String { get }
}

struct ProvisioningProfile: Equatable, Encodable {
    let path: AbsolutePath
    let name: String
    let targetName: String
    let configurationName: String
    let uuid: String
    let teamIds: [String]
    let appId: String
    let appIdName: String
    let applicationIdPrefix: [String]
    let platforms: [String]
    let expirationDate: Date
    let developerCertificateFingerprints: [String]

    struct Content {
        let name: String
        let uuid: String
        let teamIds: [String]
        let appId: String
        let appIdName: String
        let applicationIdPrefix: [String]
        let platforms: [String]
        let expirationDate: Date
        let developerCertificates: [Data]
    }
}

extension ProvisioningProfile.Content: Decodable {
    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case uuid = "UUID"
        case teamIds = "TeamIdentifier"
        case appIdName = "AppIDName"
        case applicationIdPrefix = "ApplicationIdentifierPrefix"
        case platforms = "Platform"
        case entitlements = "Entitlements"
        case expirationDate = "ExpirationDate"
        case developerCertificates = "DeveloperCertificates"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.uuid = try container.decode(String.self, forKey: .uuid)
        self.teamIds = try container.decode([String].self, forKey: .teamIds)
        self.appIdName = try container.decode(String.self, forKey: .appIdName)
        self.applicationIdPrefix = try container.decode([String].self, forKey: .applicationIdPrefix)
        self.platforms = try container.decode([String].self, forKey: .platforms)
        let entitlements = try Self.platformEntitlements(container, for: platforms)
        self.appId = entitlements.appId
        self.expirationDate = try container.decode(Date.self, forKey: .expirationDate)
        self.developerCertificates = try container.decode([Data].self, forKey: .developerCertificates)
    }

    private static func platformEntitlements(
        _ container: KeyedDecodingContainer<ProvisioningProfile.Content.CodingKeys>,
        for platforms: [String]
    ) throws -> Entitlements {
        if platforms.contains("OSX") {
            try container.decode(DesktopEntitlements.self, forKey: .entitlements)
        } else {
            try container.decode(MobileEntitlements.self, forKey: .entitlements)
        }
    }
}

extension ProvisioningProfile.Content {
    private struct MobileEntitlements: Entitlements {
        private(set) var appId: String

        enum CodingKeys: String, CodingKey {
            case appId = "application-identifier"
        }
    }

    private struct DesktopEntitlements: Entitlements {
        private(set) var appId: String

        enum CodingKeys: String, CodingKey {
            case appId = "com.apple.application-identifier"
        }
    }
}
