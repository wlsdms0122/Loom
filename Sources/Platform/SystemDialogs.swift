/// 알림 스타일 열거형.
public enum AlertStyle: Sendable {
    case informational
    case warning
    case critical
}

/// 알림 응답 열거형.
public enum AlertResponse: Sendable {
    case ok
    case cancel
    case custom(Int)
}

/// 시스템 다이얼로그 프로토콜.
public protocol SystemDialogs: Sendable {
    /// 알림 다이얼로그를 표시한다.
    func showAlert(
        title: String,
        message: String,
        style: AlertStyle
    ) async -> AlertResponse

    /// 파일 열기 다이얼로그를 표시한다.
    func showOpenPanel(
        title: String,
        allowedFileTypes: [String],
        allowsMultipleSelection: Bool,
        canChooseDirectories: Bool
    ) async -> [String]

    /// 파일 저장 다이얼로그를 표시한다.
    func showSavePanel(
        title: String,
        defaultFileName: String
    ) async -> String?
}
