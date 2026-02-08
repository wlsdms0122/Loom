import Foundation
import Platform

/// Shared mock FileWatcher for testing. Records start/stop calls.
public final class MockFileWatcher: FileWatcher, @unchecked Sendable {
    // MARK: - Property

    private let _lock = NSLock()
    private var _startCount: Int = 0
    private var _stopCount: Int = 0
    private var _watchingDirectory: String?

    public var startCount: Int { _lock.withLock { _startCount } }
    public var stopCount: Int { _lock.withLock { _stopCount } }
    public var watchingDirectory: String? { _lock.withLock { _watchingDirectory } }

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func start(watching directory: String, onChange: @escaping @Sendable () -> Void) throws {
        _lock.withLock {
            _startCount += 1
            _watchingDirectory = directory
        }
    }

    public func stop() {
        _lock.withLock {
            _stopCount += 1
            _watchingDirectory = nil
        }
    }
}
