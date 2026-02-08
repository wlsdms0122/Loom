import Foundation

/// 콘솔 출력 기반 로거 구현체.
public struct PrintLogger: Logger, Sendable {
    // MARK: - Property

    public let minLevel: LogLevel

    /// 타임스탬프 포맷터. ISO 8601 형식으로 출력한다.
    // 안전성: ISO8601DateFormatter는 초기화 후 읽기 전용 사용 시 스레드 안전하다.
    nonisolated(unsafe) private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Initializer

    public init(minLevel: LogLevel = .debug) {
        self.minLevel = minLevel
    }

    // MARK: - Public

    public func write(_ level: LogLevel, _ message: String, file: String, line: Int) {
        let timestamp = Self.formatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        print("\(timestamp) [\(level.rawValue.uppercased())] \(fileName):\(line) - \(message)")
    }
}
