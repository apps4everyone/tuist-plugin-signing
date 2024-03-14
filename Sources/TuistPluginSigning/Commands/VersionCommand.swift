import Foundation
import ArgumentParser
import TuistPluginSigningFramework

extension MainCommand {
    struct VersionCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "version",
            abstract: "Outputs the current version of the plugin."
        )

        func run() throws {
            VersionService()
                .run()
        }
    }
}
