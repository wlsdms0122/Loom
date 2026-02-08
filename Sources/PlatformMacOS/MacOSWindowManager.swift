import AppKit
import WebKit
import Core
import Platform

/// macOS 윈도우 관리자 구현체.
// 안전성: @unchecked Sendable — 이 타입은 @MainActor로 격리되어 있다.
// 모든 접근이 메인 스레드에서 직렬화된다.
@MainActor
public final class MacOSWindowManager: WindowManager, @unchecked Sendable {
    // MARK: - Property
    private var windows: [String: NSWindow] = [:]

    /// 마지막 윈도우가 닫힐 때 앱을 종료할지 여부.
    public var terminateOnLastWindowClose: Bool = true

    public var windowCount: Int { windows.count }

    // MARK: - Initializer
    public init() {
        // 윈도우 닫기 알림을 감시하여 마지막 윈도우 닫힘을 감지한다.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let closedWindow = notification.object as? NSWindow else { return }
            Task { @MainActor in
                self.handleWindowClose(closedWindow)
            }
        }
    }

    // MARK: - Public
    public func createWindow(configuration: WindowConfiguration) -> WindowHandle {
        let id = UUID().uuidString
        return createWindow(id: id, configuration: configuration)
    }

    public func createWindow(id: String, configuration: WindowConfiguration) -> WindowHandle {
        let rect = NSRect(
            x: 0,
            y: 0,
            width: configuration.width,
            height: configuration.height
        )

        var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if configuration.resizable {
            styleMask.insert(.resizable)
        }

        // 타이틀바가 숨김 스타일인 경우, 웹 콘텐츠가 윈도우 전체를 채우도록 설정한다.
        if configuration.titlebarStyle == .hidden {
            styleMask.insert(.fullSizeContentView)
        }

        let window = NSWindow(
            contentRect: rect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = configuration.title
        window.center()

        // 타이틀바가 숨김 스타일인 경우, 타이틀바를 투명하게 설정한다.
        if configuration.titlebarStyle == .hidden {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }

        if let minWidth = configuration.minWidth,
           let minHeight = configuration.minHeight {
            window.minSize = NSSize(width: minWidth, height: minHeight)
        }

        windows[id] = window

        return WindowHandle(id: id, title: configuration.title)
    }

    public func attachWebView(_ webView: any NativeWebView, to handle: WindowHandle) async {
        guard let window = windows[handle.id],
              let wkWebView = webView.nativeView as? WKWebView else { return }
        wkWebView.frame = window.contentLayoutRect
        wkWebView.autoresizingMask = [.width, .height]
        window.contentView = wkWebView

        // 윈도우 환경 정보를 CSS 변수로 주입한다.
        var env = WebEnvironment()
        if window.titlebarAppearsTransparent {
            let titlebarHeight = window.frame.height - window.contentLayoutRect.height
            env.set("--loom-titlebar-height", value: "\(Int(titlebarHeight))px", as: .css)
        }

        let script = env.injectionScript()
        if !script.isEmpty {
            await webView.addUserScript(script, injectionTime: .atDocumentStart)
        }
    }

    public func closeWindow(_ handle: WindowHandle) {
        windows[handle.id]?.close()
        windows.removeValue(forKey: handle.id)
    }

    public func showWindow(_ handle: WindowHandle) {
        guard let window = windows[handle.id] else { return }
        window.makeKeyAndOrderFront(nil)

        // 웹 뷰가 first responder가 되어야 Edit 메뉴의 표준 액션이 활성화된다.
        if let contentView = window.contentView {
            window.makeFirstResponder(contentView)
        }
    }

    public func performDrag(_ handle: WindowHandle) {
        guard let window = windows[handle.id] else { return }

        let mouseLocation = window.mouseLocationOutsideOfEventStream
        guard let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: mouseLocation,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        ) else { return }

        window.performDrag(with: event)
    }

    // MARK: - Private
    /// 윈도우 식별자로 NSWindow를 반환한다.
    func window(for id: String) -> NSWindow? {
        windows[id]
    }

    /// 윈도우 닫기 알림을 처리한다. 관리 중인 윈도우를 제거하고, 모든 윈도우가 닫히면 앱을 종료한다.
    private func handleWindowClose(_ closedWindow: NSWindow) {
        // 관리 중인 윈도우 목록에서 닫힌 윈도우를 찾아 제거한다.
        let closedId = windows.first { $0.value === closedWindow }?.key
        if let closedId {
            windows.removeValue(forKey: closedId)
        }

        // 마지막 윈도우가 닫히고 종료 옵션이 활성화된 경우 앱을 종료한다.
        if windows.isEmpty && terminateOnLastWindowClose {
            NSApp.terminate(nil)
        }
    }
}
