import Foundation
import Platform

/// NativeWebView에 대한 고수준 래퍼 프로토콜.
///
/// `WebEngine`은 NativeWebView가 제공하는 웹 뷰 기능 위에
/// SDK 주입, delegate 이벤트 처리 등 부가 기능을 추가하기 위한 레이어이다.
///
/// ## Passthrough 설계
/// 대부분의 메서드(`load`, `evaluateJavaScript`, `addMessageHandler`, `cleanup` 등)는
/// default extension을 통해 NativeWebView에 그대로 위임된다. 이는 의도된 설계로,
/// 구현체가 별도의 커스터마이징 없이도 NativeWebView의 기능을 즉시 사용할 수 있게 한다.
///
/// ## 고유 가치
/// 이 레이어의 핵심 차별점은 `delegate` 메커니즘을 통한 `NavigationPolicy` 제어이다.
/// `DefaultWebEngine`에서 delegate 설정 시 `bindNavigationPolicyHandler()`를 연결하여
/// 네비게이션 정책을 외부에서 제어할 수 있도록 한다.
public protocol WebEngine: Sendable {
    /// URL을 로드한다.
    func load(url: URL) async

    /// HTML 문자열을 로드한다.
    func load(html: String) async

    /// JavaScript를 실행한다.
    func evaluateJavaScript(_ script: String) async throws -> (any Sendable)?

    /// Bridge SDK를 주입한다.
    func injectBridgeSDK(_ sdk: String) async

    /// 메시지 핸들러를 등록한다.
    func addMessageHandler(name: String, handler: @escaping @Sendable (Any) async -> Void) async

    /// 등록된 메시지 핸들러와 리소스를 정리하여 순환 참조를 해제한다.
    func cleanup() async

    /// 현재 페이지를 다시 로드한다.
    @MainActor func reload() async

    /// 델리게이트. 웹 엔진 이벤트를 수신한다.
    var delegate: (any WebEngineDelegate)? { get set }

    /// 내부 NativeWebView를 반환한다.
    var webView: any NativeWebView { get }
}

// MARK: - Default Implementation
// 아래 기본 구현들은 NativeWebView에 대한 의도적 passthrough이다.
// 구현체는 필요에 따라 개별 메서드를 재정의할 수 있다.
extension WebEngine {
    /// URL을 로드한다. 기본적으로 NativeWebView에 위임한다.
    public func load(url: URL) async {
        await webView.loadURL(url)
    }

    /// HTML 문자열을 로드한다. 기본적으로 NativeWebView에 위임한다.
    public func load(html: String) async {
        await webView.loadHTML(html)
    }

    /// JavaScript를 실행한다. 기본적으로 NativeWebView에 위임한다.
    public func evaluateJavaScript(_ script: String) async throws -> (any Sendable)? {
        try await webView.evaluateJavaScript(script)
    }

    /// Bridge SDK를 주입한다. 기본적으로 문서 시작 시점에 주입한다.
    public func injectBridgeSDK(_ sdk: String) async {
        await webView.addUserScript(sdk, injectionTime: .atDocumentStart)
    }

    /// 메시지 핸들러를 등록한다. 기본적으로 NativeWebView에 위임한다.
    public func addMessageHandler(name: String, handler: @escaping @Sendable (Any) async -> Void) async {
        await webView.addMessageHandler(name: name, handler: handler)
    }

    /// 리소스를 정리한다. 기본적으로 NativeWebView에 위임한다.
    public func cleanup() async {
        await webView.cleanup()
    }
}
