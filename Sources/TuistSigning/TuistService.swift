import Foundation
import TSCBasic
import TuistLoader
import TuistSupport

enum TuistServiceError: Error {
    case taskUnavailable
}

final class TuistService: NSObject {
    private let configLoader: ConfigLoading

    init(
        configLoader: ConfigLoading = ConfigLoader(manifestLoader: CachedManifestLoader())
    ) {
        self.configLoader = configLoader
        logger.info("TuistService.init()")
    }

    func run(
        arguments: [String]
    ) throws {
        logger.info("TuistService.run(arguments: \(arguments.debugDescription)")
        try System.shared.runAndPrint(
            arguments,
            verbose: Environment.shared.isVerbose,
            environment: [:]
        )
    }
}
