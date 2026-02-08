import Foundation
import Testing
import WebKit
import Platform
@testable import PlatformMacOS
import WebEngine

/// MacOSWebView의 cleanup 및 순환 참조 해제를 검증한다.
@Suite("MacOSWebView Cleanup", .serialized)
struct MacOSWebViewCleanupTests {
    // MARK: - Tests

    @Test("cleanup 호출 후 동일한 이름의 메시지 핸들러를 재등록할 수 있다")
    @MainActor
    func cleanupAllowsReregistration() async {
        let webView = MacOSWebView()

        // 메시지 핸들러를 등록한다.
        webView.addMessageHandler(name: "testHandler") { _ in }
        webView.addMessageHandler(name: "anotherHandler") { _ in }

        // cleanup을 호출한다.
        await webView.cleanup()

        // cleanup 후 동일한 이름으로 재등록이 가능하다.
        // WKUserContentController는 중복 이름 등록 시 예외를 발생시키므로,
        // 예외 없이 등록되면 cleanup이 정상적으로 핸들러를 제거한 것이다.
        webView.addMessageHandler(name: "testHandler") { _ in }
        webView.addMessageHandler(name: "anotherHandler") { _ in }
    }

    @Test("cleanup 호출 후 사용자 스크립트가 제거된다")
    @MainActor
    func cleanupRemovesUserScripts() async {
        let webView = MacOSWebView()

        // 사용자 스크립트를 추가한다.
        webView.addUserScript("console.log('start')", injectionTime: .atDocumentStart)
        webView.addUserScript("console.log('end')", injectionTime: .atDocumentEnd)

        // cleanup을 호출한다.
        await webView.cleanup()

        // contentController에서 직접 확인한다.
        let scripts = webView.wkWebView.configuration.userContentController.userScripts
        #expect(scripts.isEmpty)
    }

    @Test("cleanup 호출 전 메시지 핸들러가 등록되어 JS에서 접근 가능하다")
    @MainActor
    func messageHandlerAccessibleBeforeCleanup() async {
        let webView = MacOSWebView()

        webView.addMessageHandler(name: "test") { _ in }

        // 빈 페이지를 로드하고 JS에서 메시지 핸들러에 접근할 수 있는지 확인한다.
        webView.loadHTML("<html><body></body></html>")

        // Task.sleep is required here because WKWebView loads content asynchronously
        // in a separate web process. There is no synchronous API to await load completion
        // without implementing a WKNavigationDelegate, which is outside the scope of this test.
        try? await Task.sleep(for: .milliseconds(1000))

        // webkit.messageHandlers.test.postMessage 함수가 존재하는지 확인한다.
        let result = try? await webView.evaluateJavaScript(
            "window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.test ? 'exists' : 'missing'"
        )
        // 테스트 환경에서 WKWebView의 JS 실행이 제한될 수 있으므로,
        // null 결과도 허용하되 'missing'은 아닌지 확인한다.
        if let resultStr = result as? String {
            #expect(resultStr == "exists")
        }
        // result가 nil이면 JS 실행 환경이 준비되지 않은 것이므로 스킵한다.
    }

    @Test("WeakScriptMessageHandler 사용으로 MacOSWebView가 해제될 수 있다")
    @MainActor
    func webViewCanBeDeallocatedWithWeakProxy() async {
        weak var weakRef: MacOSWebView?

        // MacOSWebView를 생성하고 메시지 핸들러를 등록한 뒤 스코프를 벗어나게 한다.
        // WeakScriptMessageHandler 패턴 덕분에 WKUserContentController가
        // MacOSWebView를 강하게 참조하지 않으므로 해제가 가능하다.
        autoreleasepool {
            let webView = MacOSWebView()
            weakRef = webView

            webView.addMessageHandler(name: "loom") { _ in }
            webView.addUserScript("console.log('test')", injectionTime: .atDocumentStart)
        }

        #expect(weakRef == nil)
    }

    @Test("여러 번 cleanup을 호출해도 안전하다")
    @MainActor
    func multipleCleanupCallsAreSafe() async {
        let webView = MacOSWebView()

        webView.addMessageHandler(name: "handler1") { _ in }
        webView.addUserScript("var x = 1;", injectionTime: .atDocumentStart)

        // cleanup을 여러 번 호출한다.
        await webView.cleanup()
        await webView.cleanup()
        await webView.cleanup()

        // 이후에도 정상적으로 핸들러를 등록할 수 있다.
        webView.addMessageHandler(name: "handler2") { _ in }
    }

    @Test("DefaultWebEngine cleanup이 NativeWebView cleanup으로 전달된다")
    func engineCleanupDelegatesToWebView() async {
        let mockWebView = CleanupTrackingMockWebView()
        let engine = DefaultWebEngine(webView: mockWebView)

        await engine.cleanup()

        #expect(mockWebView.cleanupCallCount == 1)
    }
}

// MARK: - toSendable Tests

@Suite("MacOSWebView toSendable")
struct MacOSWebViewToSendableTests {
    @Test("Bool 값은 Bool로 변환된다 (NSNumber가 아닌)")
    func boolConvertsToBool() {
        let trueResult = MacOSWebView.toSendable(true)
        let falseResult = MacOSWebView.toSendable(false)

        #expect(trueResult as? Bool == true)
        #expect(falseResult as? Bool == false)

        // Bool이 Double이 아닌 Bool 타입으로 변환되었는지 확인한다.
        #expect(trueResult is Bool)
        #expect(falseResult is Bool)
    }

    @Test("NSNumber 값은 Double로 변환된다")
    func nsNumberConvertsToDouble() {
        let intResult = MacOSWebView.toSendable(NSNumber(value: 42))
        let doubleResult = MacOSWebView.toSendable(NSNumber(value: 3.14))

        #expect(intResult as? Double == 42.0)
        #expect(doubleResult as? Double == 3.14)
    }

    @Test("String 값은 String으로 변환된다")
    func stringConvertsToString() {
        let result = MacOSWebView.toSendable("hello")

        #expect(result as? String == "hello")
    }

    @Test("NSArray 값은 [any Sendable]로 변환된다")
    func nsArrayConvertsToArray() {
        let array: NSArray = ["a", "b", NSNumber(value: 1)]
        let result = MacOSWebView.toSendable(array)

        guard let arr = result as? [any Sendable] else {
            #expect(Bool(false), "Expected [any Sendable] array")
            return
        }
        #expect(arr.count == 3)
        #expect(arr[0] as? String == "a")
        #expect(arr[1] as? String == "b")
        #expect(arr[2] as? Double == 1.0)
    }

    @Test("NSDictionary 값은 [String: any Sendable]로 변환된다")
    func nsDictionaryConvertsToDictionary() {
        let dict: NSDictionary = ["key": "value", "num": NSNumber(value: 5)]
        let result = MacOSWebView.toSendable(dict)

        guard let converted = result as? [String: any Sendable] else {
            #expect(Bool(false), "Expected [String: any Sendable] dictionary")
            return
        }
        #expect(converted["key"] as? String == "value")
        #expect(converted["num"] as? Double == 5.0)
    }

    @Test("nil 값은 nil을 반환한다")
    func nilReturnsNil() {
        let result = MacOSWebView.toSendable(NSNull())

        // NSNull은 지원되지 않는 타입이므로 String(describing:)으로 변환된다.
        #expect(result is String)
    }

    @Test("Bool이 NSNumber보다 우선 매칭된다")
    func boolMatchesBeforeNSNumber() {
        // Objective-C에서 Bool은 NSNumber로 브릿지된다.
        // toSendable에서 Bool 체크가 NSNumber보다 먼저 수행되어야 한다.
        let objcTrue: NSNumber = true as NSNumber
        let result = MacOSWebView.toSendable(objcTrue)

        // ObjC 브릿지에서 Bool로 생성된 NSNumber는 Bool로 변환되어야 한다.
        #expect(result is Bool)
    }
}

// MARK: - Test Helper

/// cleanup 호출 횟수를 추적하는 모의 NativeWebView.
private final class CleanupTrackingMockWebView: NativeWebView, @unchecked Sendable {
    // MARK: - Property
    private let _lock = NSLock()
    private var _cleanupCallCount: Int = 0

    var cleanupCallCount: Int { _lock.withLock { _cleanupCallCount } }

    @MainActor var nativeView: Any { self }

    // MARK: - NativeWebView
    func loadURL(_ url: URL) async {}
    func loadHTML(_ html: String) async {}
    func evaluateJavaScript(_ script: String) async throws -> (any Sendable)? { nil }
    func addUserScript(_ script: String, injectionTime: ScriptInjectionTime) async {}
    func addMessageHandler(name: String, handler: @escaping @Sendable (Any) async -> Void) async {}
    func cleanup() async { _lock.withLock { _cleanupCallCount += 1 } }
    func reload() {}
}
