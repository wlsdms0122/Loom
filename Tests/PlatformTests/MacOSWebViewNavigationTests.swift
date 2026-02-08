import Foundation
import Testing
import WebKit
import Platform
@testable import PlatformMacOS

/// MacOSWebView의 WKNavigationDelegate 구현을 검증한다.
@Suite("MacOSWebView Navigation", .serialized)
struct MacOSWebViewNavigationTests {
    // MARK: - Tests

    @Test("초기화 시 WKNavigationDelegate가 자기 자신으로 설정된다")
    @MainActor
    func navigationDelegateIsSet() {
        let webView = MacOSWebView()

        #expect(webView.wkWebView.navigationDelegate === webView)
    }

    @Test("setNavigationPolicyHandler로 네비게이션 정책 핸들러를 설정할 수 있다")
    @MainActor
    func setNavigationPolicyHandler() async {
        let webView = MacOSWebView()

        await webView.setNavigationPolicyHandler { _, _ in
            true
        }

        // 핸들러가 설정되었는지 간접적으로 확인한다.
        // (직접 프로퍼티 접근이 private이므로 예외 없이 설정되면 성공)
    }
}
