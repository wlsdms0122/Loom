import Core

/// Shared stub Logger for testing. Discards all log messages.
public struct StubLogger: Logger, Sendable {
    public init() {}

    public func write(_ level: LogLevel, _ message: String, file: String, line: Int) {}
}
