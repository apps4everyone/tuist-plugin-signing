import Foundation
import ArgumentParser
import OSLog
import Path
import TuistSupport

let logger = Logger()

@available(macOS 14, *)
@main
public struct MainCommand: AsyncParsableCommand {
    public init() {}

    public static var configuration: CommandConfiguration {
        #if DEBUG
        CommandConfiguration(
            commandName: "plugin-signing",
            abstract: "A set of commands for signing-related operations",
            subcommands: [
                VersionCommand.self,
                EncryptCommand.self,
                DecryptCommand.self,
                InstallCommand.self,
                ExportCommand.self
            ],
            defaultSubcommand: ExportCommand.self
        )
        #else
        CommandConfiguration(
            commandName: "plugin-signing",
            abstract: "A set of commands for signing-related operations",
            subcommands: [
                VersionCommand.self,
                EncryptCommand.self,
                DecryptCommand.self,
                InstallCommand.self,
                ExportCommand.self
            ]
        )
        #endif
    }

    public func run() async throws {
        logger.info("MainCommand.run()")
    }
}

extension MainCommand {
    static func absolutePath(path: String? = nil) throws -> AbsolutePath {
        var absolutePath: AbsolutePath?
        if let path {
            absolutePath = try? AbsolutePath(validating: path)
        } else {
            #if DEBUG
            if let baselineFile = ProcessInfo.processInfo.environment["TUIST_PROJECT_PATH"] {
                absolutePath = try AbsolutePath.root.appending(
                    RelativePath(validating: baselineFile)
                )
            } else {
                absolutePath = FileHandler.shared.currentPath
            }
            #else
            absolutePath = FileHandler.shared.currentPath
            #endif
        }
        guard let absolutePath else {
            throw "AbsolutePath missing"
        }
        return absolutePath
    }
}
