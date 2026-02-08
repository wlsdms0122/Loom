import AppKit
import Testing
import Platform
@testable import Core
@testable import PlatformMacOS

/// MacOSWindowManager의 타이틀바 스타일 처리를 검증한다.
@Suite("MacOSWindowManager 타이틀바", .serialized)
@MainActor
struct MacOSWindowManagerTitlebarTests {
    // MARK: - Tests

    @Test("기본 titlebarStyle(.visible)은 표준 타이틀바를 생성한다")
    func defaultTitlebar() {
        let manager = MacOSWindowManager()
        manager.terminateOnLastWindowClose = false

        let config = WindowConfiguration()
        let handle = manager.createWindow(id: "visible-test", configuration: config)

        let window = manager.window(for: handle.id)
        #expect(window != nil)
        #expect(window!.titlebarAppearsTransparent == false)
        #expect(!window!.styleMask.contains(.fullSizeContentView))
    }

    @Test("hidden titlebarStyle은 투명 타이틀바를 생성한다")
    func hiddenTitlebar() {
        let manager = MacOSWindowManager()
        manager.terminateOnLastWindowClose = false

        let config = WindowConfiguration(titlebarStyle: .hidden)
        let handle = manager.createWindow(id: "hidden-test", configuration: config)

        let window = manager.window(for: handle.id)
        #expect(window != nil)
        #expect(window!.titlebarAppearsTransparent == true)
        #expect(window!.titleVisibility == .hidden)
        #expect(window!.styleMask.contains(.fullSizeContentView))
    }

    @Test("hidden 타이틀바 윈도우에 WebView 연결 시 CSS 변수를 주입한다")
    func hiddenTitlebarInjectsCSSVariable() async {
        let manager = MacOSWindowManager()
        manager.terminateOnLastWindowClose = false

        let config = WindowConfiguration(titlebarStyle: .hidden)
        let handle = manager.createWindow(id: "css-inject-test", configuration: config)

        let webView = MacOSWebView()

        // 연결 전 사용자 스크립트가 비어 있는지 확인한다.
        let scriptsBefore = webView.wkWebView.configuration.userContentController.userScripts
        #expect(scriptsBefore.isEmpty)

        await manager.attachWebView(webView, to: handle)

        // 연결 후 CSS 변수를 주입하는 사용자 스크립트가 추가되었는지 확인한다.
        let scriptsAfter = webView.wkWebView.configuration.userContentController.userScripts
        #expect(!scriptsAfter.isEmpty)

        // 주입된 스크립트에 --loom-titlebar-height CSS 변수가 포함되어 있는지 확인한다.
        let containsTitlebarHeight = scriptsAfter.contains { script in
            script.source.contains("--loom-titlebar-height")
        }
        #expect(containsTitlebarHeight)
    }

    @Test("visible 타이틀바 윈도우에 WebView 연결 시 CSS 변수를 주입하지 않는다")
    func visibleTitlebarNoCSSVariable() async {
        let manager = MacOSWindowManager()
        manager.terminateOnLastWindowClose = false

        let config = WindowConfiguration()
        let handle = manager.createWindow(id: "no-css-test", configuration: config)

        let webView = MacOSWebView()
        await manager.attachWebView(webView, to: handle)

        // 기본 타이틀바에서는 CSS 변수를 주입하지 않으므로 사용자 스크립트가 비어 있어야 한다.
        let scripts = webView.wkWebView.configuration.userContentController.userScripts
        let containsTitlebarHeight = scripts.contains { script in
            script.source.contains("--loom-titlebar-height")
        }
        #expect(!containsTitlebarHeight)
    }
}
