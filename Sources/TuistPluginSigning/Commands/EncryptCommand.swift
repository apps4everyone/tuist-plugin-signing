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

            let absolutePath = AbsolutePath(stringLiteral: path)

            let loader = RecursiveManifestLoader()

            let loadedWorkspace: LoadedWorkspace = try loader.loadWorkspace(at: absolutePath)

            let graphLoading = GraphLoader()

            let manifestModelConverter = ManifestModelConverter()

            let workspace = try manifestModelConverter.convert(
                manifest: loadedWorkspace.workspace,
                path: absolutePath
            )

            let graph: Graph = try graphLoading.loadWorkspace(
                workspace: workspace,
                projects: []
            )

            let graphTraverser = GraphTraverser(graph: graph)
            
            let signingInteractor = SigningInteractor()

            let issues = try signingInteractor.install(graphTraverser: graphTraverser)
            
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

            try EncryptService().run(path: self.path)
        }
    }
}
