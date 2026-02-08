import Foundation
import Platform

/// Shared mock NativeWebView for testing. Records all method calls and arguments.
public final class MockNativeWebView: NativeWebView, @unchecked Sendable {
    // MARK: - Property

    private let _lock = NSLock()
    private var _loadedURLs: [URL] = []
    private var _loadedHTMLs: [String] = []
    private var _evaluatedScripts: [String] = []
    private var _userScripts: [(script: String, injectionTime: ScriptInjectionTime)] = []
    private var _messageHandlers: [String: @Sendable (Any) async -> Void] = [:]
    private var _evaluateResult: (any Sendable)?
    private var _reloadCount: Int = 0
    private var _cleanupCount: Int = 0
    private var _navigationPolicyHandler: NavigationPolicyHandler?

    public var loadedURLs: [URL] { _lock.withLock { _loadedURLs } }
    public var loadedHTMLs: [String] { _lock.withLock { _loadedHTMLs } }
    public var evaluatedScripts: [String] { _lock.withLock { _evaluatedScripts } }
    public var userScripts: [(script: String, injectionTime: ScriptInjectionTime)] { _lock.withLock { _userScripts } }
    public var messageHandlerNames: [String] { _lock.withLock { Array(_messageHandlers.keys).sorted() } }
    public var reloadCount: Int { _lock.withLock { _reloadCount } }
    public var cleanupCount: Int { _lock.withLock { _cleanupCount } }
    public var navigationPolicyHandler: NavigationPolicyHandler? { _lock.withLock { _navigationPolicyHandler } }

    @MainActor public var nativeView: Any { self }

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func setEvaluateResult(_ result: any Sendable) {
        _lock.withLock { _evaluateResult = result }
    }

    public func loadURL(_ url: URL) async {
        _lock.withLock { _loadedURLs.append(url) }
    }

    public func loadHTML(_ html: String) async {
        _lock.withLock { _loadedHTMLs.append(html) }
    }

    public func evaluateJavaScript(_ script: String) async throws -> (any Sendable)? {
        _lock.withLock {
            _evaluatedScripts.append(script)
            return _evaluateResult
        }
    }

    public func addUserScript(_ script: String, injectionTime: ScriptInjectionTime) async {
        _lock.withLock { _userScripts.append((script: script, injectionTime: injectionTime)) }
    }

    public func addMessageHandler(name: String, handler: @escaping @Sendable (Any) async -> Void) async {
        _lock.withLock { _messageHandlers[name] = handler }
    }

    public func cleanup() async {
        _lock.withLock {
            _messageHandlers.removeAll()
            _userScripts.removeAll()
            _cleanupCount += 1
        }
    }

    public func reload() {
        _lock.withLock { _reloadCount += 1 }
    }

    public func setNavigationPolicyHandler(_ handler: @escaping NavigationPolicyHandler) async {
        _lock.withLock { _navigationPolicyHandler = handler }
    }

    /// Invokes a registered message handler by name.
    public func simulateMessage(name: String, body: Any) async {
        let handler = _lock.withLock { _messageHandlers[name] }
        await handler?(body)
    }

    /// 네비게이션 정책 핸들러를 호출하여 테스트에서 네비게이션을 시뮬레이션한다.
    public func simulateNavigation(url: URL, isMainFrame: Bool) async -> Bool {
        let handler = _lock.withLock { _navigationPolicyHandler }
        return await handler?(url, isMainFrame) ?? true
    }
}
