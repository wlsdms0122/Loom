import Foundation

// MARK: - TitlebarStyle

/// 타이틀바 스타일.
public enum TitlebarStyle: Sendable {
    /// 기본 OS 타이틀바를 표시한다.
    case visible

    /// 타이틀바를 숨기고 웹 콘텐츠가 윈도우 전체를 채운다. 트래픽 라이트 버튼은 오버레이로 표시된다.
    case hidden
}

/// 윈도우 크기 및 옵션을 정의하는 구조체.
public struct WindowConfiguration: Sendable {
    // MARK: - Property
    public let width: Double
    public let height: Double
    public let minWidth: Double?
    public let minHeight: Double?
    public let title: String
    public let resizable: Bool
    public let titlebarStyle: TitlebarStyle

    // MARK: - Initializer
    public init(
        width: Double = 800,
        height: Double = 600,
        minWidth: Double? = nil,
        minHeight: Double? = nil,
        title: String = "",
        resizable: Bool = true,
        titlebarStyle: TitlebarStyle = .visible
    ) {
        self.width = width
        self.height = height
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.title = title
        self.resizable = resizable
        self.titlebarStyle = titlebarStyle
    }
}
