import Foundation
import Platform

/// WebEngine의 기본 구현체. NativeWebView를 래핑하여 SDK 주입 및 메시지 핸들링을 제공한다.
// 안전성: @unchecked Sendable — NativeWebView, WebEngineDelegate는 모두
// Sendable을 준수한다. 가변 프로퍼티 `delegate`는 NSLock으로 동기화하여 data race를 방지한다.
public final class DefaultWebEngine: WebEngine, @unchecked Sendable {
    // MARK: - Property
    public let webView: any NativeWebView
    private var _delegate: (any WebEngineDelegate)?
    private let _delegateLock = NSLock()
    public var delegate: (any WebEngineDelegate)? {
        get {
            _delegateLock.lock()
            defer { _delegateLock.unlock() }
            return _delegate
        }
        set {
            _delegateLock.lock()
            _delegate = newValue
            _delegateLock.unlock()
            bindNavigationPolicyHandler()
        }
    }

    // MARK: - Initializer
    public init(
        webView: any NativeWebView
    ) {
        self.webView = webView
    }

    // MARK: - Public
    @MainActor
    public func reload() {
        webView.reload()
    }

    // MARK: - Private
    /// delegate의 decidePolicyFor를 NativeWebView의 NavigationPolicyHandler로 연결한다.
    private func bindNavigationPolicyHandler() {
        guard let delegate else { return }
        let capturedDelegate = delegate
        Task {
            await webView.setNavigationPolicyHandler { url, isMainFrame in
                let action = NavigationAction(url: url, isMainFrame: isMainFrame)
                let policy = await capturedDelegate.webEngine(decidePolicyFor: action)
                return policy == .allow
            }
        }
    }
}
