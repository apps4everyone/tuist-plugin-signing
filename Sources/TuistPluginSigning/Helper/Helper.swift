import Foundation
import Path
import TuistSupport

// MARK: - Helpers

extension AbsolutePath {
    static func path(_ path: String?) throws -> AbsolutePath {
        if let path {
            return try AbsolutePath(
                validating: path,
                relativeTo: FileHandler.shared.currentPath
            )
        } else {
            return FileHandler.shared.currentPath
        }
    }
}
