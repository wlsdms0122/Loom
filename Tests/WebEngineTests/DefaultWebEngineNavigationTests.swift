import Testing
import Foundation
import Platform
@testable import WebEngine
import LoomTestKit

/// DefaultWebEngine의 delegate 설정 시 네비게이션 정책 핸들러 연결을 검증한다.
@Suite("DefaultWebEngine Navigation")
struct DefaultWebEngineNavigationTests {
    // MARK: - Property

    private let webView: MockNativeWebView
    private let engine: DefaultWebEngine

    // MARK: - Initializer

    init() {
        webView = MockNativeWebView()
        engine = DefaultWebEngine(webView: webView)
    }

    // MARK: - Tests

    @Test("delegate 설정 시 NativeWebView에 네비게이션 정책 핸들러가 등록된다")
    func delegateBindsNavigationHandler() async throws {
        let mockDelegate = MockWebEngineDelegate()
        engine.delegate = mockDelegate

        // Task 내부에서 비동기로 핸들러를 설정하므로 잠시 대기한다.
        try await Task.sleep(for: .milliseconds(100))

        let handler = webView.navigationPolicyHandler
        #expect(handler != nil)
    }

    @Test("delegate의 decidePolicyFor가 allow를 반환하면 핸들러도 true를 반환한다")
    func delegateAllowReturnsTrue() async throws {
        let mockDelegate = MockWebEngineDelegate()
        mockDelegate.navigationPolicy = .allow
        engine.delegate = mockDelegate

        try await Task.sleep(for: .milliseconds(100))

        let url = URL(string: "https://example.com")!
        let result = await webView.simulateNavigation(url: url, isMainFrame: true)
        #expect(result == true)
    }

    @Test("delegate의 decidePolicyFor가 cancel을 반환하면 핸들러도 false를 반환한다")
    func delegateCancelReturnsFalse() async throws {
        let mockDelegate = MockWebEngineDelegate()
        mockDelegate.navigationPolicy = .cancel
        engine.delegate = mockDelegate

        try await Task.sleep(for: .milliseconds(100))

        let url = URL(string: "https://external.com")!
        let result = await webView.simulateNavigation(url: url, isMainFrame: true)
        #expect(result == false)
    }

    @Test("delegate에 전달되는 NavigationAction의 URL과 isMainFrame이 정확하다")
    func navigationActionPassedCorrectly() async throws {
        let mockDelegate = MockWebEngineDelegate()
        engine.delegate = mockDelegate

        try await Task.sleep(for: .milliseconds(100))

        let url = URL(string: "https://test.com/page")!
        _ = await webView.simulateNavigation(url: url, isMainFrame: false)

        #expect(mockDelegate.receivedActions.count == 1)
        #expect(mockDelegate.receivedActions.first?.url == url)
        #expect(mockDelegate.receivedActions.first?.isMainFrame == false)
    }

    @Test("delegate가 nil이면 네비게이션 정책 핸들러가 설정되지 않는다")
    func noDelegateNoHandler() async throws {
        // delegate를 설정하지 않았으므로 핸들러가 nil이어야 한다.
        let handler = webView.navigationPolicyHandler
        #expect(handler == nil)
    }
}

// MARK: - MockWebEngineDelegate

/// 네비게이션 정책 테스트를 위한 모의 WebEngineDelegate.
private final class MockWebEngineDelegate: WebEngineDelegate, @unchecked Sendable {
    // MARK: - Property
    private let _lock = NSLock()
    var navigationPolicy: NavigationPolicy = .allow
    private var _receivedActions: [NavigationAction] = []

    var receivedActions: [NavigationAction] { _lock.withLock { _receivedActions } }

    // MARK: - WebEngineDelegate
    func webEngine(decidePolicyFor action: NavigationAction) async -> NavigationPolicy {
        _lock.withLock { _receivedActions.append(action) }
        return navigationPolicy
    }
}
