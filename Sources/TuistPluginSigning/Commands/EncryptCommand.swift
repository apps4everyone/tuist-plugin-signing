import Foundation
import TuistPluginSigningFramework
import ArgumentParser

extension MainCommand {
    struct EncryptCommand: ParsableCommand {
        static var configuration: CommandConfiguration {
            CommandConfiguration(
                commandName: "encrypt",
                abstract: "Encrypts all files in Tuist/Signing directory"
            )
        }
        
        @Option(
            name: .shortAndLong,
            help: "The path to the folder containing the certificates you would like to encrypt",
            completion: .directory
        )
        var path: String?
        
        func run() async throws {
            logger.info("EncryptCommand.run()")

            guard let path else {
                throw "No path"
            }

            try await EncryptService().run(path: path)
        }
    }
}
