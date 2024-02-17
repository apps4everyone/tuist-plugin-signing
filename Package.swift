// swift-tools-version: 5.9
import PackageDescription

let version = Version("4.2.5")

let package = Package(
    name: "tuist-plugin-signing",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "tuist-plugin-signing",
            targets: [.tuistPluginSigning]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/tuist/tuist",
            exact: version
        ),
        .package(
            url: "https://github.com/apple/swift-tools-support-core",
            exact: "0.6.1"
        ),
        .package(
            url: "https://github.com/krzyzanowskim/CryptoSwift",
            exact: "1.8.0"
        ),
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            exact: "1.3.0"
        )
    ],
    targets: [
        .executableTarget(
            name: .tuistPluginSigning,
            dependencies: [
                .byName(name: .tuistPluginSigningFramework),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .target(
            name: .tuistPluginSigningFramework,
            dependencies: [
                .product(name: "TSCBasic", package: "swift-tools-support-core"),
                .product(name: "TuistCore", package: "tuist"),
                .product(name: "TuistLoader", package: "tuist"),
                .product(name: "TuistGraph", package: "tuist"),
                .product(name: "TuistSupport", package: "tuist"),
                .product(name: "TuistKit", package: "tuist"),
                //.product(name: "ProjectDescription", package: "tuist"),
                .product(name: "CryptoSwift", package: "CryptoSwift")
            ]
        )/*,
        .binaryTarget(
            name: "ProjectDescription",
            url: "https://github.com/tuist/tuist/releases/download/\(version.description)/ProjectDescription.xcframework.zip",
            checksum: "426a773837ad5ea824ff572eadee02225d9fd67a92c85a60180b03fd48807968c6ab5daa781b88cf7bdb396a85d58ae39b15cee5f80337fe9cc5056affdde7c4"
        ),
        .testTarget(
            name: .tuistPluginSigningTesting,
            dependencies: [
                .byName(name: .tuistPluginSigning)
            ]
        )
        */
    ]
)

extension String {
    static let tuistPluginSigning = "TuistPluginSigning"
    static let tuistPluginSigningFramework = "TuistPluginSigningFramework"
    //static let tuistPluginSigningTesting = "TuistPluginSigningTesting"
}
