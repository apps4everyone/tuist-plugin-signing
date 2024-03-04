import Foundation
import ArgumentParser

extension MainCommand {
    struct DecryptCommand: ParsableCommand {
        static var configuration: CommandConfiguration {
            CommandConfiguration(
                commandName: "decrypt",
                abstract: "Decrypts all files in Tuist/Signing directory"
            )
        }

        @Option(
            name: .shortAndLong,
            help: "The path to the folder containing the encrypted certificates",
            completion: .directory
        )
        var path: String?

        func run() throws {
            logger.info("DecryptCommand.run()")

            guard let path else {
                logger.error("No path")
                return
            }

            try DecryptService().run(path: path)
        }
    }
}
