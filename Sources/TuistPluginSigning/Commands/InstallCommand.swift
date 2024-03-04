import Foundation
import TuistPluginSigningFramework
import TSCBasic
import TuistGraph
import TuistSupport
import TuistCore
import TuistGraph
import TSCBasic
import TuistLoader
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

        public func run() async throws {
            logger.info("TestCommand.run()")

            try! await self.install()
        }

        private func install() async throws {
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
                assertionFailure("absolutePath missing")
                return
            }

            logger.info("\(absolutePath)")

            let graph: ProjectAutomation.Graph = try Tuist.graph()

            let signingInteractor = SigningInteractor()

            let issues = try signingInteractor.install(
                path: absolutePath,
                graph: graph
            )

            let warnings = issues.filter { lintingIssue in
                lintingIssue.severity == .warning
            }
            warnings.forEach { issue in
                logger.warning("\(issue.reason)")
            }

            let errors = issues.filter { lintingIssue in
                lintingIssue.severity == .error
            }
            guard errors.count > 0 else {
                issues.forEach { issue in
                    logger.error("\(issue.reason)")
                }
                return
            }
        }
    }
}
