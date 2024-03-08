import Foundation
import ArgumentParser
import OSLog

let logger = Logger()

/// The entry point of the plugin. Main command that must be invoked in `main.swift` file.

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
