import Foundation
import Path

struct Certificate: Equatable {
    let publicKey: AbsolutePath
    let privateKey: AbsolutePath
    let fingerprint: String
    let developmentTeam: String
    let name: String
    let isRevoked: Bool
}
