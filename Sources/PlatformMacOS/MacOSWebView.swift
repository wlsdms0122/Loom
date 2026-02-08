import Foundation
import WebKit
import Core
import Platform

// MARK: - WeakScriptMessageHandler
/// WKUserContentController의 강한 참조로 인한 순환 참조를 방지하기 위한 약한 프록시.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    // MARK: - Property
    weak var delegate: (any WKScriptMessageHandler)?

    // MARK: - Initializer
    init(delegate: any WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    // MARK: - WKScriptMessageHandler
    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(controller, didReceive: message)
    }
}

/// macOS 웹 뷰 구현체. WKWebView를 래핑한다.
// 안전성: @unchecked Sendable — 이 타입은 @MainActor로 격리되어 있다.
// 모든 접근이 메인 스레드에서 직렬화된다.
@MainActor
public final class MacOSWebView: NSObject, NativeWebView, @unchecked Sendable {
    // MARK: - Property
    private let webView: WKWebView
    private let contentController: WKUserContentController
    private var messageHandlers: [String: @Sendable (Any) async -> Void] = [:]
    private var registeredHandlerNames: Set<String> = []
    private var navigationPolicyHandler: NavigationPolicyHandler?

    /// 내부 WKWebView에 접근한다.
    public var wkWebView: WKWebView { webView }

    /// 플랫폼 고유의 네이티브 뷰 객체에 접근한다.
    public var nativeView: Any { webView }

    // MARK: - Initializer
    public override init() {
        let config = WKWebViewConfiguration()
        self.contentController = config.userContentController
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.navigationDelegate = self

        #if DEBUG
        webView.isInspectable = true
        #endif
    }

    /// WindowConfiguration을 사용하여 초기 프레임 크기를 설정한다.
    public init(
        configuration: WindowConfiguration,
        schemeHandlers: [(scheme: String, handler: any WKURLSchemeHandler)] = []
    ) {
        let frame = NSRect(
            x: 0,
            y: 0,
            width: configuration.width,
            height: configuration.height
        )
        let config = WKWebViewConfiguration()

        for (scheme, handler) in schemeHandlers {
            config.setURLSchemeHandler(handler, forURLScheme: scheme)
        }

        self.contentController = config.userContentController
        self.webView = WKWebView(frame: frame, configuration: config)
        super.init()

        webView.navigationDelegate = self

        #if DEBUG
        webView.isInspectable = true
        #endif
    }

    // MARK: - Public

    /// DEBUG 빌드에서 JS console 메서드를 Swift Logger로 포워딩한다.
    /// console.log/warn/error/info 호출을 가로채어 loomConsole 메시지 핸들러로 전달한다.
    public func enableConsoleForwarding(logger: any Logger) {
        #if DEBUG
        // console 메서드를 오버라이드하여 메시지 핸들러로 전달하는 스크립트를 주입한다.
        let consoleScript = """
        (function() {
            const levels = ['log', 'warn', 'error', 'info'];
            levels.forEach(function(level) {
                const original = console[level].bind(console);
                console[level] = function() {
                    const args = Array.from(arguments).map(function(arg) {
                        try { return typeof arg === 'object' ? JSON.stringify(arg) : String(arg); }
                        catch(e) { return String(arg); }
                    });
                    const message = args.join(' ');
                    window.webkit.messageHandlers.loomConsole.postMessage(
                        JSON.stringify({ level: level, message: message })
                    );
                    original.apply(console, arguments);
                };
            });
        })();
        """
        addUserScript(consoleScript, injectionTime: .atDocumentStart)

        // loomConsole 메시지 핸들러를 등록하여 Logger로 포워딩한다.
        addMessageHandler(name: "loomConsole") { body in
            guard let bodyString = body as? String,
                  let data = bodyString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  let level = json["level"],
                  let message = json["message"] else {
                return
            }

            let formatted = "[JS:\(level)] \(message)"
            switch level {
            case "error":
                logger.error(formatted)
            case "warn":
                logger.warning(formatted)
            case "info":
                logger.info(formatted)
            default:
                logger.debug(formatted)
            }
        }
        #endif
    }

    public func loadURL(_ url: URL) {
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    public func loadHTML(_ html: String) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    public func evaluateJavaScript(_ script: String) async throws -> (any Sendable)? {
        guard let result = try await webView.evaluateJavaScript(script) else {
            return nil
        }
        return MacOSWebView.toSendable(result)
    }

    public func addUserScript(_ script: String, injectionTime: ScriptInjectionTime) {
        let wkTime: WKUserScriptInjectionTime = switch injectionTime {
        case .atDocumentStart: .atDocumentStart
        case .atDocumentEnd: .atDocumentEnd
        }

        let userScript = WKUserScript(
            source: script,
            injectionTime: wkTime,
            forMainFrameOnly: true
        )
        contentController.addUserScript(userScript)
    }

    public func addMessageHandler(
        name: String,
        handler: @escaping @Sendable (Any) async -> Void
    ) {
        // 이미 등록된 핸들러가 있으면 제거한 후 재등록한다.
        if registeredHandlerNames.contains(name) {
            contentController.removeScriptMessageHandler(forName: name)
        }

        messageHandlers[name] = handler
        registeredHandlerNames.insert(name)
        let proxy = WeakScriptMessageHandler(delegate: self)
        contentController.add(proxy, name: name)
    }

    public func setNavigationPolicyHandler(_ handler: @escaping NavigationPolicyHandler) {
        navigationPolicyHandler = handler
    }

    public func cleanup() async {
        contentController.removeAllScriptMessageHandlers()
        contentController.removeAllUserScripts()
        registeredHandlerNames.removeAll()
        messageHandlers.removeAll()
    }

    public func reload() {
        webView.reload()
    }

    // MARK: - Private
    /// JavaScript 결과를 Sendable 호환 타입으로 변환한다.
    nonisolated static func toSendable(_ value: Any) -> (any Sendable)? {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            // Bool은 Objective-C에서 NSNumber로 브릿지되므로
            // CFBoolean 타입을 먼저 확인하여 Bool과 일반 숫자를 구분한다.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue
            }
            return number.doubleValue
        case let array as NSArray:
            return array.compactMap { toSendable($0) }
        case let dict as NSDictionary:
            var result: [String: any Sendable] = [:]
            for (key, val) in dict {
                if let keyStr = key as? String {
                    result[keyStr] = toSendable(val)
                }
            }
            return result
        default:
            return String(describing: value)
        }
    }
}

// MARK: - WKScriptMessageHandler
extension MacOSWebView: WKScriptMessageHandler {
    public nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            let name = message.name
            let body = message.body
            guard let handler = self.messageHandlers[name] else { return }
            await handler(body)
        }
    }
}

// MARK: - WKNavigationDelegate
extension MacOSWebView: WKNavigationDelegate {
    public nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        // MainActor 접근을 한 번에 모아서 컨텍스트 전환 횟수를 줄인다.
        let (url, isMainFrame, handler) = await MainActor.run {
            (
                navigationAction.request.url,
                navigationAction.targetFrame?.isMainFrame ?? true,
                self.navigationPolicyHandler
            )
        }

        guard let url else {
            return .allow
        }

        // about:blank 등 비-HTTP 스킴은 항상 허용한다.
        guard url.scheme == "http" || url.scheme == "https" else {
            return .allow
        }

        // 네비게이션 정책 핸들러가 설정된 경우 핸들러에 위임한다.
        if let handler {
            let allowed = await handler(url, isMainFrame)
            if !allowed {
                await MainActor.run { _ = NSWorkspace.shared.open(url) }
                return .cancel
            }
            return .allow
        }

        // 핸들러가 없으면 기본 정책을 적용한다.
        return await MainActor.run {
            decidePolicyDefault(for: url, currentURL: webView.url)
        }
    }

    /// 기본 네비게이션 정책을 반환한다. 동일 출처는 허용하고 외부 URL은 기본 브라우저에서 연다.
    @MainActor
    private func decidePolicyDefault(
        for url: URL,
        currentURL: URL?
    ) -> WKNavigationActionPolicy {
        // 최초 로드 시(currentURL이 nil)에는 허용한다.
        guard let currentURL else {
            return .allow
        }

        // 동일 출처(same-origin)인지 확인한다.
        if currentURL.host == url.host {
            return .allow
        }

        // 외부 URL은 기본 브라우저에서 열고 웹 뷰 내 네비게이션은 차단한다.
        NSWorkspace.shared.open(url)
        return .cancel
    }
}
