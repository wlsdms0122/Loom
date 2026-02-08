import Core

/// 플랫폼 제공자 프로토콜. 각 OS별 구현을 추상화한다.
@MainActor
public protocol PlatformProvider: Sendable {
    /// 윈도우 관리자를 생성한다.
    func makeWindowManager() -> any WindowManager

    /// 웹 뷰를 생성한다.
    func makeWebView(configuration: WindowConfiguration) -> any NativeWebView

    /// 진입점 정보를 포함하여 웹 뷰를 생성한다.
    /// 플랫폼 구현체는 진입점 유형에 따라 커스텀 스킴 핸들러를 내부적으로 설정할 수 있다.
    func makeWebView(configuration: WindowConfiguration, entry: EntryPoint) -> any NativeWebView

    /// 파일 시스템 접근자를 생성한다.
    func makeFileSystem() -> any FileSystem

    /// 시스템 다이얼로그를 생성한다.
    func makeDialogs() -> any SystemDialogs

    /// 클립보드 접근자를 생성한다.
    func makeClipboard() -> any Clipboard

    /// 셸 유틸리티를 생성한다.
    func makeShell() -> any Shell

    /// 상태 아이템(시스템 트레이 / 메뉴바)을 생성한다.
    func makeStatusItem() -> (any StatusItem)?

    /// 파일 변경 감시자를 생성한다. 플랫폼이 지원하지 않으면 nil을 반환한다.
    func makeFileWatcher() -> (any FileWatcher)?

    /// 시스템 정보.
    var system: SystemInfo { get }

    /// 메뉴 항목을 애플리케이션 메뉴바에 적용한다.
    /// 반환값은 메뉴 빌더에 대한 참조로, 호출자가 유지해야 메뉴 타겟이 해제되지 않는다.
    func applyMenu(_ items: [MenuItem]) -> AnyObject?
}

// MARK: - Default Implementation
extension PlatformProvider {
    /// 기본적으로 진입점을 무시하고 기존 makeWebView(configuration:)로 위임한다.
    public func makeWebView(configuration: WindowConfiguration, entry: EntryPoint) -> any NativeWebView {
        makeWebView(configuration: configuration)
    }

    /// 기본적으로 메뉴 적용을 지원하지 않는다.
    public func applyMenu(_ items: [MenuItem]) -> AnyObject? {
        nil
    }

    /// 기본적으로 파일 감시를 지원하지 않는다.
    public func makeFileWatcher() -> (any FileWatcher)? {
        nil
    }

    /// 기본적으로 상태 아이템을 지원하지 않는다.
    public func makeStatusItem() -> (any StatusItem)? {
        nil
    }
}
