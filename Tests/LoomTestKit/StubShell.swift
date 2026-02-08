import Foundation
import Platform

/// Shared stub Shell for testing.
public final class StubShell: Shell, @unchecked Sendable {
    // MARK: - Property

    private let _lock = NSLock()
    private var _openedURLs: [URL] = []
    private var _openedPaths: [String] = []

    public var openedURLs: [URL] { _lock.withLock { _openedURLs } }
    public var openedPaths: [String] { _lock.withLock { _openedPaths } }

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func openURL(_ url: URL) async -> Bool {
        _lock.withLock { _openedURLs.append(url) }
        return true
    }

    public func openPath(_ path: String) async -> Bool {
        _lock.withLock { _openedPaths.append(path) }
        return true
    }
}
