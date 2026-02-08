import Foundation

// MARK: - NavigationAction

/// 네비게이션 요청 정보를 나타낸다. WKNavigationAction의 플랫폼 독립적 추상화.
public struct NavigationAction: Sendable {
    /// 요청 URL.
    public let url: URL

    /// 네비게이션이 현재 프레임에서 발생했는지 여부.
    public let isMainFrame: Bool

    public init(url: URL, isMainFrame: Bool) {
        self.url = url
        self.isMainFrame = isMainFrame
    }
}

// MARK: - NavigationPolicy

/// 네비게이션 허용 여부를 나타내는 열거형.
public enum NavigationPolicy: Sendable {
    /// 네비게이션을 허용한다.
    case allow

    /// 네비게이션을 취소한다.
    case cancel
}

// MARK: - WebEngineDelegate

/// 웹 엔진 델리게이트 프로토콜. 웹 엔진 이벤트를 수신한다.
public protocol WebEngineDelegate: Sendable {
    /// 네비게이션 요청에 대한 정책을 결정한다.
    func webEngine(decidePolicyFor action: NavigationAction) async -> NavigationPolicy
}

// MARK: - Default Implementation

public extension WebEngineDelegate {
    func webEngine(decidePolicyFor action: NavigationAction) async -> NavigationPolicy {
        .allow
    }
}
