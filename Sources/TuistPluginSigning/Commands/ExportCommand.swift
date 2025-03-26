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
    struct ExportCommand: AsyncParsableCommand {
        public static var configuration: CommandConfiguration {
            CommandConfiguration(
                commandName: "export",
                abstract: "A command for exporting the ProvisioningProfiles.json and Certificates.json into the /CodeSigning folder"
            )
        }

        @Option(
            name: .shortAndLong,
            help: "The path to the folder containing the manifest",
            completion: .directory
        )
        var path: String?

        func run() async throws {
            logger.info("ExportCommand.run()")

            try await self.export()
        }

        private func export() async throws {
            let absolutePath: AbsolutePath = try MainCommand.absolutePath(path: self.path)
            logger.info("\(absolutePath)")

            let graph: ProjectAutomation.Graph = try Tuist.graph(
                at: absolutePath.pathString
            )
            let signingInteractor = SigningInteractor()
            try await signingInteractor.export(
                path: absolutePath,
                graph: graph
            )
        }
    }
}
