import Testing
import Foundation
import Core
import Platform
import LoomTestKit

/// 멀티 윈도우 지원을 검증한다.
/// 여러 윈도우 생성, 독립성, 닫기, 윈도우 수 추적을 테스트한다.
@Suite("멀티 윈도우 테스트")
struct MultiWindowTests {
    // MARK: - Property

    private let windowManager: MockWindowManager

    // MARK: - Initializer

    init() {
        windowManager = MockWindowManager()
    }

    // MARK: - Tests

    @Test("여러 윈도우를 생성하면 각각 독립적인 핸들을 반환한다")
    func createMultipleWindowsReturnsIndependentHandles() async {
        let config1 = WindowConfiguration(
            width: 800,
            height: 600,
            title: "Window 1"
        )
        let config2 = WindowConfiguration(
            width: 1024,
            height: 768,
            title: "Window 2"
        )
        let config3 = WindowConfiguration(
            width: 640,
            height: 480,
            title: "Window 3"
        )

        let handle1 = await windowManager.createWindow(configuration: config1)
        let handle2 = await windowManager.createWindow(configuration: config2)
        let handle3 = await windowManager.createWindow(configuration: config3)

        // 각 핸들의 ID가 고유한지 확인한다.
        #expect(handle1.id != handle2.id)
        #expect(handle2.id != handle3.id)
        #expect(handle1.id != handle3.id)

        // 각 핸들의 제목이 올바른지 확인한다.
        #expect(handle1.title == "Window 1")
        #expect(handle2.title == "Window 2")
        #expect(handle3.title == "Window 3")

        // 생성된 설정 수가 올바른지 확인한다.
        #expect(windowManager.createdConfigurations.count == 3)
    }

    @Test("지정된 ID로 윈도우를 생성할 수 있다")
    func createWindowWithSpecificId() async {
        let config = WindowConfiguration(title: "Named Window")

        let handle = await windowManager.createWindow(id: "my-settings", configuration: config)

        #expect(handle.id == "my-settings")
        #expect(handle.title == "Named Window")
    }

    @Test("윈도우 수가 올바르게 추적된다")
    func windowCountTracking() async {
        #expect(windowManager.windowCount == 0)

        let config = WindowConfiguration(title: "Test")
        let handle1 = await windowManager.createWindow(configuration: config)
        #expect(windowManager.windowCount == 1)

        let _ = await windowManager.createWindow(configuration: config)
        #expect(windowManager.windowCount == 2)

        let _ = await windowManager.createWindow(configuration: config)
        #expect(windowManager.windowCount == 3)

        // 윈도우 하나를 닫는다.
        await windowManager.closeWindow(handle1)
        #expect(windowManager.windowCount == 2)
    }

    @Test("하나의 윈도우를 닫아도 다른 윈도우는 유지된다")
    func closeOneWindowOthersRemain() async {
        let config1 = WindowConfiguration(title: "Main")
        let config2 = WindowConfiguration(title: "Settings")
        let config3 = WindowConfiguration(title: "Preview")

        let handle1 = await windowManager.createWindow(configuration: config1)
        let handle2 = await windowManager.createWindow(configuration: config2)
        let handle3 = await windowManager.createWindow(configuration: config3)

        #expect(windowManager.windowCount == 3)

        // 두 번째 윈도우를 닫는다.
        await windowManager.closeWindow(handle2)

        #expect(windowManager.windowCount == 2)
        #expect(windowManager.closedHandles.count == 1)
        #expect(windowManager.closedHandles.first == handle2)

        // 나머지 윈도우는 여전히 표시할 수 있다.
        await windowManager.showWindow(handle1)
        await windowManager.showWindow(handle3)
        #expect(windowManager.shownHandles.count == 2)
    }

    @Test("모든 윈도우를 닫으면 윈도우 수가 0이 된다")
    func closeAllWindowsResultsInZeroCount() async {
        let config = WindowConfiguration(title: "Temp")

        let handle1 = await windowManager.createWindow(configuration: config)
        let handle2 = await windowManager.createWindow(configuration: config)

        #expect(windowManager.windowCount == 2)

        await windowManager.closeWindow(handle1)
        await windowManager.closeWindow(handle2)

        #expect(windowManager.windowCount == 0)
    }

    @Test("각 윈도우에 독립적으로 WebView를 연결할 수 있다")
    func attachWebViewsIndependently() async {
        let config1 = WindowConfiguration(title: "Editor")
        let config2 = WindowConfiguration(title: "Preview")

        let handle1 = await windowManager.createWindow(configuration: config1)
        let handle2 = await windowManager.createWindow(configuration: config2)

        let webView1 = MockNativeWebView()
        let webView2 = MockNativeWebView()

        await windowManager.attachWebView(webView1, to: handle1)
        await windowManager.attachWebView(webView2, to: handle2)

        #expect(windowManager.attachedCount == 2)
        #expect(windowManager.attachedWebViewCount == 2)
    }

    @Test("지정 ID로 생성한 윈도우와 자동 ID 윈도우가 공존한다")
    func namedAndAutoIdWindowsCoexist() async {
        let config = WindowConfiguration(title: "Test")

        let namedHandle = await windowManager.createWindow(
            id: "settings-panel",
            configuration: config
        )
        let autoHandle = await windowManager.createWindow(configuration: config)

        #expect(namedHandle.id == "settings-panel")
        #expect(namedHandle.id != autoHandle.id)
        #expect(windowManager.windowCount == 2)

        // 이름 지정 윈도우를 닫는다.
        await windowManager.closeWindow(namedHandle)
        #expect(windowManager.windowCount == 1)

        // 자동 ID 윈도우는 여전히 유효하다.
        await windowManager.showWindow(autoHandle)
        #expect(windowManager.shownHandles.count == 1)
        #expect(windowManager.shownHandles.first == autoHandle)
    }

    @Test("단일 윈도우 생성/표시/닫기가 정상 동작한다")
    func singleWindowLifecycle() async {
        let config = WindowConfiguration(
            width: 800,
            height: 600,
            title: "Single Window"
        )

        let handle = await windowManager.createWindow(configuration: config)

        #expect(windowManager.windowCount == 1)
        #expect(handle.title == "Single Window")

        await windowManager.showWindow(handle)
        #expect(windowManager.shownHandles.count == 1)

        await windowManager.closeWindow(handle)
        #expect(windowManager.windowCount == 0)
    }
}
