import Foundation

/// 셸 유틸리티 프로토콜. URL 열기, 경로 열기 등의 기능을 추상화한다.
public protocol Shell: Sendable {
    /// URL을 기본 핸들러로 연다.
    func openURL(_ url: URL) async -> Bool

    /// Finder에서 해당 경로를 연다.
    func openPath(_ path: String) async -> Bool
}
