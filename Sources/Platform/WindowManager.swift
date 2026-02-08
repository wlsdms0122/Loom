import Core

/// 윈도우 관리 프로토콜.
public protocol WindowManager: Sendable {
    /// 현재 관리 중인 윈도우 수.
    var windowCount: Int { get async }

    /// 마지막 윈도우가 닫힐 때 앱을 종료할지 여부.
    @MainActor var terminateOnLastWindowClose: Bool { get set }

    /// 새 윈도우를 생성한다.
    func createWindow(configuration: WindowConfiguration) async -> WindowHandle

    /// 지정된 ID로 새 윈도우를 생성한다.
    func createWindow(id: String, configuration: WindowConfiguration) async -> WindowHandle

    /// 윈도우에 웹 뷰를 연결한다.
    func attachWebView(_ webView: any NativeWebView, to handle: WindowHandle) async

    /// 윈도우를 닫는다.
    func closeWindow(_ handle: WindowHandle) async

    /// 윈도우를 표시한다.
    func showWindow(_ handle: WindowHandle) async

    /// 윈도우 드래그를 시작한다.
    func performDrag(_ handle: WindowHandle) async
}

// MARK: - Default Implementation

extension WindowManager {
    public func performDrag(_ handle: WindowHandle) async {}
}
