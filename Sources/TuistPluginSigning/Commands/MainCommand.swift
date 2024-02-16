import Foundation
import ArgumentParser
import OSLog

let logger = Logger()

/// The entry point of the plugin. Main command that must be invoked in `main.swift` file.

public struct MainCommand: AsyncParsableCommand {
    public init() {}

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "plugin-signing",
            abstract: "A set of commands for signing-related operations",
            subcommands: [
                VersionCommand.self,
                EncryptCommand.self,
                DecryptCommand.self
            ],
            defaultSubcommand: VersionCommand.self
        )
    }

    public func run() throws {
        logger.info("MainCommand.run()")
    }
}
