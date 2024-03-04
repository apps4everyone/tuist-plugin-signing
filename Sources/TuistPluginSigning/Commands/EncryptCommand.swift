import Foundation
import TuistPluginSigningFramework
import TSCBasic
import ArgumentParser
import TuistGraph
import TuistSupport
import TuistCore
import TuistGraph
import TuistLoader

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
        
        func run() throws {
            logger.info("EncryptCommand.run()")

            guard let path else {
                logger.error("No path")
                return
            }

            try EncryptService().run(path: path)
        }
    }
}
