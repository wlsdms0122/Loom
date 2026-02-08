import Foundation
import Platform

/// Shared stub FileSystem for testing. Stores files in memory.
public final class StubFileSystem: FileSystem, @unchecked Sendable {
    // MARK: - Property

    private let lock = NSLock()
    private var _files: [String: Data] = [:]
    private var _directories: Set<String> = []

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func exists(at path: String) -> Bool {
        lock.withLock { _files[path] != nil || _directories.contains(path) }
    }

    public func readData(at path: String) throws -> Data {
        try lock.withLock {
            guard let data = _files[path] else {
                throw StubFileSystemError.fileNotFound(path)
            }
            return data
        }
    }

    public func writeData(_ data: Data, to path: String) throws {
        lock.withLock { _files[path] = data }
    }

    public func delete(at path: String) throws {
        lock.withLock {
            _files.removeValue(forKey: path)
            _directories.remove(path)
        }
    }

    public func createDirectory(at path: String) throws {
        lock.withLock { _directories.insert(path) }
    }

    public func listContents(at path: String) throws -> [String] {
        lock.withLock {
            let prefix = path.hasSuffix("/") ? path : path + "/"
            var entries: [String] = []
            for key in _files.keys {
                if key.hasPrefix(prefix) {
                    let remaining = String(key.dropFirst(prefix.count))
                    if !remaining.contains("/") {
                        entries.append(remaining)
                    }
                }
            }
            return entries.sorted()
        }
    }
}

/// StubFileSystem errors.
public enum StubFileSystemError: Error {
    case fileNotFound(String)
}
