import Testing
import Foundation
import Platform
@testable import WebEngine
import LoomTestKit

/// DefaultWebEngine의 웹 뷰 관리 및 SDK 주입 기능을 검증한다.
@Suite("DefaultWebEngine")
struct DefaultWebEngineTests {
    // MARK: - Property

    private let webView: MockNativeWebView
    private let engine: DefaultWebEngine

    // MARK: - Initializer

    init() {
        webView = MockNativeWebView()
        engine = DefaultWebEngine(webView: webView)
    }

    // MARK: - Tests

    @Test("URL 로드 시 NativeWebView에 전달된다")
    func loadURL() async {
        let url = URL(string: "https://example.com")!
        await engine.load(url: url)

        #expect(webView.loadedURLs.count == 1)
        #expect(webView.loadedURLs.first == url)
    }

    @Test("HTML 로드 시 NativeWebView에 전달된다")
    func loadHTML() async {
        let html = "<html><body>Hello</body></html>"
        await engine.load(html: html)

        #expect(webView.loadedHTMLs.count == 1)
        #expect(webView.loadedHTMLs.first == html)
    }

    @Test("JavaScript 실행 시 NativeWebView에 전달되고 결과를 반환한다")
    func evaluateJavaScript() async throws {
        webView.setEvaluateResult("hello")
        let result = try await engine.evaluateJavaScript("getGreeting()")

        #expect(webView.evaluatedScripts.count == 1)
        #expect(webView.evaluatedScripts.first == "getGreeting()")
        #expect(result as? String == "hello")
    }

    @Test("Bridge SDK 주입 시 atDocumentStart 타이밍으로 UserScript가 등록된다")
    func injectBridgeSDK() async {
        let sdk = "window.loom = {};"
        await engine.injectBridgeSDK(sdk)

        #expect(webView.userScripts.count == 1)
        #expect(webView.userScripts.first?.script == sdk)
        #expect(webView.userScripts.first?.injectionTime == .atDocumentStart)
    }

    @Test("메시지 핸들러 등록 시 NativeWebView에 전달된다")
    func addMessageHandler() async {
        await engine.addMessageHandler(name: "loom") { _ in }

        #expect(webView.messageHandlerNames == ["loom"])
    }

    @Test("여러 URL을 순차적으로 로드할 수 있다")
    func loadMultipleURLs() async {
        let url1 = URL(string: "https://example.com/1")!
        let url2 = URL(string: "https://example.com/2")!

        await engine.load(url: url1)
        await engine.load(url: url2)

        #expect(webView.loadedURLs.count == 2)
        #expect(webView.loadedURLs == [url1, url2])
    }

    @Test("webView 프로퍼티가 주입된 NativeWebView를 반환한다")
    func webViewProperty() {
        let view = engine.webView
        #expect(view is MockNativeWebView)
    }

    @Test("reload이 NativeWebView의 reload을 호출한다")
    @MainActor
    func reload() {
        engine.reload()

        #expect(webView.reloadCount == 1)
    }
}
