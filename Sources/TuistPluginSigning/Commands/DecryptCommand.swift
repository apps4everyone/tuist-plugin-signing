import Foundation
import ArgumentParser
import Path

extension MainCommand {
    struct DecryptCommand: AsyncParsableCommand {
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

        func run() async throws {
            logger.info("DecryptCommand.run()")

            let absolutePath: AbsolutePath = try MainCommand.absolutePath(path: self.path)
            logger.info("\(absolutePath)")
            
            try await DecryptService().run(path: absolutePath)
        }
    }
}
