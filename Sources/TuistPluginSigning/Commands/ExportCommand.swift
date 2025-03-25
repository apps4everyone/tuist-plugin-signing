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

        public func run() async throws {
            logger.info("ExportCommand.run()")

            try await self.export()
        }

        private func export() async throws {
            var absolutePath: AbsolutePath?
            if let path {
                absolutePath = try? AbsolutePath(validating: path)
            } else {
                #if DEBUG
                if let baselineFile = ProcessInfo.processInfo.environment["TUIST_PROJECT_PATH"] {
                    absolutePath = try AbsolutePath.root.appending(
                        RelativePath(validating: baselineFile)
                    )
                } else {
                    absolutePath = FileHandler.shared.currentPath
                }
                #else
                absolutePath = FileHandler.shared.currentPath
                #endif
            }
            guard let absolutePath else {
                throw "AbsolutePath missing"
            }

            logger.info("\(absolutePath)")

            let graph: ProjectAutomation.Graph = try Tuist.graph()

            let signingInteractor = SigningInteractor()

            try await signingInteractor.export(
                path: absolutePath,
                graph: graph
            )
        }
    }
}
