import Foundation
import Core

/// 기록된 로그 메시지.
public struct LogEntry: Sendable {
    public let level: LogLevel
    public let message: String

    public init(level: LogLevel, message: String) {
        self.level = level
        self.message = message
    }
}

/// 로그 메시지를 기록하는 스파이 로거. 테스트에서 로그 출력을 검증할 때 사용한다.
// SAFETY: @unchecked Sendable is safe because all mutable state (`_entries`)
// is protected by `_lock` (NSLock).
public final class SpyLogger: Logger, @unchecked Sendable {
    // MARK: - Property

    private let _lock = NSLock()
    private var _entries: [LogEntry] = []

    /// 기록된 모든 로그 엔트리를 반환한다.
    public var entries: [LogEntry] {
        _lock.withLock { _entries }
    }

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func write(_ level: LogLevel, _ message: String, file: String, line: Int) {
        _lock.withLock {
            _entries.append(LogEntry(level: level, message: message))
        }
    }
}
