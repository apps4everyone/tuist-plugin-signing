import ArgumentParser
import Foundation
import TSCBasic

public struct SigningCommand: AsyncParsableCommand {
    public init() {}

    public static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "signing",
            abstract: "A set of commands for signing-related operations",
            subcommands: [
                EncryptCommand.self,
                DecryptCommand.self,
            ]
        )
    }

    public func run() throws {
        logger.info("SigningCommand.run()")

        let processedArguments = Self.processArguments()
        logger.info("SigningCommand.run() processArguments: \(processedArguments.debugDescription)")
    }

    public static func main() async {
        logger.info("SigningCommand.main()")

        let execute = Self.execute
        let executeCommand: () async throws -> Void
        let processedArguments = Self.processArguments()
        
        logger.info("SigningCommand processArguments: \(processedArguments.debugDescription)")

        var parsedError: Error?
        do {
            let command = try parseAsRoot(processedArguments)
            executeCommand = {
                try await execute(
                    command,
                    processedArguments
                )
            }
        } catch {
            parsedError = error
            executeCommand = {
                try self.executeTask(with: processedArguments)
            }
        }

        do {
            defer { }
            try await executeCommand()
        } catch let error {
            if let parsedError {
                self.handleParseError(parsedError)
            }
            // Exit cleanly
            if exitCode(for: error).rawValue == 0 {
                exit(withError: error)
            } else {
                _exit(exitCode(for: error).rawValue)
            }
        }
    }

    private static func executeTask(with processedArguments: [String]) throws {
        logger.info("SigningCommand.executeTask")

        try TuistService().run(
            arguments: processedArguments
        )
    }

    private static func handleParseError(_ error: Error) -> Never {
        logger.info("SigningCommand.handleParseError")

        let exitCode = exitCode(for: error).rawValue
        _exit(exitCode)
    }

    private static func execute(
        command: ParsableCommand,
        commandArguments _: [String]
    ) async throws {
        var command = command
        if var asyncCommand = command as? AsyncParsableCommand {
            try await asyncCommand.run()
        } else {
            try command.run()
        }
    }

    // MARK: - Helpers

    static func processArguments() -> [String] {
        return Array(ProcessInfo.processInfo.arguments)
    }
}
