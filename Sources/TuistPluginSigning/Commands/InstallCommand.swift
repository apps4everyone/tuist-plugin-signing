import Foundation
import TuistPluginSigningFramework
import TSCBasic
import TuistGraph
import TuistSupport
import TuistCore
import TuistGraph
import TuistLoader
import TuistKit
import Combine

extension MainCommand {
    struct InstallCommand: AsyncParsableCommand {
        public static var configuration: CommandConfiguration {
            CommandConfiguration(
                commandName: "Install",
                abstract: "A command for Installing Certificates and ProvisioningProfiles"
            )
        }

        public func run() async throws {
            logger.info("TestCommand.run()")

            try await self.install()
        }

        private func install() async throws {
            #if DEBUG
            let absolutePath = try AbsolutePath.root.appending(
                RelativePath(validating: "Users/stefanfessler/git/EGIT/george-app-ios-48")
            )
            #else
            let absolutePath = FileHandler.shared.currentPath
            #endif
            logger.info("\(absolutePath)")

            let manifestLoader = ManifestLoaderFactory().createManifestLoader()

            let manifestGraphLoader = ManifestGraphLoader(
                manifestLoader: manifestLoader,
                workspaceMapper: SequentialWorkspaceMapper(mappers: []),
                graphMapper: SequentialGraphMapper([])
            )

            let result: (
                Graph,
                [SideEffectDescriptor],
                [LintingIssue]
            ) = try await manifestGraphLoader.load(path: absolutePath)

            let graph: Graph = result.0

            logger.info("\(graph.workspace.name)")
            logger.info("\(graph.projects.count)")

            let graphTraverser = GraphTraverser(graph: graph)

            let signingInteractor = SigningInteractor()

            let issues = try signingInteractor.install(
                graphTraverser: graphTraverser
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
