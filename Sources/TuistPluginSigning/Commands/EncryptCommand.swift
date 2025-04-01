import Foundation
import ArgumentParser
import Path

extension MainCommand {
    struct EncryptCommand: AsyncParsableCommand {
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
            
            let absolutePath: AbsolutePath = try MainCommand.absolutePath(path: self.path)
            logger.info("\(absolutePath)")

            try await EncryptService().run(path: absolutePath)
        }
    }
}
