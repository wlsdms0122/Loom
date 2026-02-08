import Foundation
import os

/// Apple os.Logger 기반 구조화된 로거 구현체.
public struct OSLogger: Logger, Sendable {
    // MARK: - Property

    public let minLevel: LogLevel

    private let logger: os.Logger

    // MARK: - Initializer

    public init(subsystem: String, category: String, minLevel: LogLevel = .debug) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
        self.minLevel = minLevel
    }

    // MARK: - Public

    public func write(_ level: LogLevel, _ message: String, file: String, line: Int) {
        let fileName = (file as NSString).lastPathComponent
        let formatted = "\(fileName):\(line) - \(message)"
        logger.log(level: level.osLogType, "\(formatted)")
    }
}

// MARK: - LogLevel + OSLogType

extension LogLevel {
    /// LogLevel을 OSLogType으로 매핑한다.
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}
