import Foundation
import TuistPluginSigningFramework
import Path
import XcodeGraph
import TuistSupport
import XcodeGraph
import Path
import TuistKit
import Combine
import ProjectAutomation

extension MainCommand {
    struct InstallCommand: AsyncParsableCommand {
        public static var configuration: CommandConfiguration {
            CommandConfiguration(
                commandName: "install",
                abstract: "A command for Installing Certificates and ProvisioningProfiles"
            )
        }

        @Option(
            name: .shortAndLong,
            help: "The path to the folder containing the manifest",
            completion: .directory
        )
        var path: String?

        func run() async throws {
            logger.info("InstallCommand.run()")

            try await self.install()
        }

        private func install() async throws {
            let absolutePath: AbsolutePath = try MainCommand.absolutePath(path: self.path)
            logger.info("\(absolutePath)")
            
            let signingInteractor = SigningInteractor()

            try await signingInteractor.install(
                path: absolutePath
            )
        }
    }
}
