import Foundation
import Platform

/// Shared stub Clipboard for testing. Stores text in memory.
public final class StubClipboard: Clipboard, @unchecked Sendable {
    // MARK: - Property

    private let lock = NSLock()
    private var _text: String?

    // MARK: - Initializer

    public init(text: String? = nil) {
        self._text = text
    }

    // MARK: - Public

    public func readText() async -> String? {
        lock.withLock { _text }
    }

    public func writeText(_ text: String) async -> Bool {
        lock.withLock {
            _text = text
            return true
        }
    }
}
