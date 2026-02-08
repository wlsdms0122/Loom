import Foundation

/// 경로만 필요한 메서드의 인자.
struct PathArgs: Codable, Sendable {
    let path: String
}
