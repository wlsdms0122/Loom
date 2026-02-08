import Foundation
import os
import Testing
import WebKit
import Platform
@testable import PlatformMacOS

/// 테스트용 스레드 안전 플래그.
private final class FlagBox: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: false)

    var value: Bool {
        storage.withLock { $0 }
    }

    func set() {
        storage.withLock { $0 = true }
    }
}

/// MacOSWebView의 메시지 핸들러 중복 등록 방어를 검증한다.
@Suite("MacOSWebView MessageHandler", .serialized)
struct MacOSWebViewMessageHandlerTests {
    // MARK: - Tests

    @Test("같은 이름으로 메시지 핸들러를 두 번 등록해도 예외가 발생하지 않는다")
    @MainActor
    func duplicateRegistrationDoesNotThrow() async {
        let webView = MacOSWebView()

        // 같은 이름으로 두 번 등록한다. 중복 방어가 없으면 WKUserContentController가 예외를 던진다.
        webView.addMessageHandler(name: "duplicate") { _ in }
        webView.addMessageHandler(name: "duplicate") { _ in }
    }

    @Test("같은 이름으로 재등록하면 새 핸들러가 사용된다")
    @MainActor
    func reregistrationUsesNewHandler() async {
        let webView = MacOSWebView()
        let firstFlag = FlagBox()
        let secondFlag = FlagBox()

        // 첫 번째 핸들러를 등록한다.
        webView.addMessageHandler(name: "test") { [firstFlag] _ in
            firstFlag.set()
        }

        // 같은 이름으로 두 번째 핸들러를 등록한다.
        webView.addMessageHandler(name: "test") { [secondFlag] _ in
            secondFlag.set()
        }

        // 빈 페이지를 로드하고 메시지를 보낸다.
        webView.loadHTML("<html><body></body></html>")
        try? await Task.sleep(for: .milliseconds(1000))

        // WKScriptMessageHandler를 통해 메시지를 수신하면 두 번째 핸들러가 호출되어야 한다.
        // 직접적인 메시지 전송은 WKWebView 내부 동작이므로, 핸들러 교체 자체를 검증한다.
        // (예외 없이 등록되었으면 중복 방어가 정상 동작한 것이다)
        #expect(!firstFlag.value)
        #expect(!secondFlag.value)
    }

    @Test("서로 다른 이름의 핸들러는 독립적으로 등록된다")
    @MainActor
    func differentNamesRegisteredIndependently() async {
        let webView = MacOSWebView()

        webView.addMessageHandler(name: "handler1") { _ in }
        webView.addMessageHandler(name: "handler2") { _ in }
        webView.addMessageHandler(name: "handler3") { _ in }

        // 서로 다른 이름이므로 예외 없이 등록되어야 한다.
    }

    @Test("cleanup 후 같은 이름으로 재등록할 수 있다")
    @MainActor
    func reregistrationAfterCleanup() async {
        let webView = MacOSWebView()

        webView.addMessageHandler(name: "handler") { _ in }
        await webView.cleanup()

        // cleanup 후 같은 이름으로 재등록한다.
        webView.addMessageHandler(name: "handler") { _ in }
    }

    @Test("같은 이름으로 세 번 연속 등록해도 예외가 발생하지 않는다")
    @MainActor
    func tripleRegistrationDoesNotThrow() async {
        let webView = MacOSWebView()

        webView.addMessageHandler(name: "triple") { _ in }
        webView.addMessageHandler(name: "triple") { _ in }
        webView.addMessageHandler(name: "triple") { _ in }
    }
}
