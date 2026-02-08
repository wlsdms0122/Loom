/// 로그 레벨 열거형.
public enum LogLevel: String, Sendable, Comparable {
    case debug
    case info
    case warning
    case error

    // MARK: - Comparable

    /// 로그 레벨의 순서 값. debug < info < warning < error.
    private var order: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.order < rhs.order
    }
}

/// 로거 프로토콜.
public protocol Logger: Sendable {
    /// 최소 로그 레벨. 이 레벨 미만의 로그는 무시된다.
    var minLevel: LogLevel { get }

    /// 로그 메시지를 출력한다.
    /// minLevel 필터링이 완료된 후에만 호출된다. 구현체에서 minLevel을 다시 확인할 필요가 없다.
    func write(_ level: LogLevel, _ message: String, file: String, line: Int)
}

extension Logger {
    /// 기본 최소 로그 레벨은 debug이다.
    public var minLevel: LogLevel { .debug }

    /// minLevel 필터링 후 write()를 호출한다.
    public func log(_ level: LogLevel, _ message: String, file: String, line: Int) {
        guard level >= minLevel else { return }
        write(level, message, file: file, line: line)
    }

    /// 디버그 레벨 로그.
    public func debug(_ message: String, file: String = #file, line: Int = #line) {
        log(.debug, message, file: file, line: line)
    }

    /// 정보 레벨 로그.
    public func info(_ message: String, file: String = #file, line: Int = #line) {
        log(.info, message, file: file, line: line)
    }

    /// 경고 레벨 로그.
    public func warning(_ message: String, file: String = #file, line: Int = #line) {
        log(.warning, message, file: file, line: line)
    }

    /// 오류 레벨 로그.
    public func error(_ message: String, file: String = #file, line: Int = #line) {
        log(.error, message, file: file, line: line)
    }
}
