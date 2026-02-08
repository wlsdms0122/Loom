import Foundation
import Platform

/// macOS 파일 시스템 구현체. FileManager를 래핑한다.
// 안전성: @unchecked Sendable — 모든 저장 프로퍼티가 불변(let)이며
// FileManager는 스레드 안전하다고 문서화되어 있다.
public struct MacOSFileSystem: FileSystem, @unchecked Sendable {
    // MARK: - Property
    private let manager: FileManager

    // MARK: - Initializer
    public init(manager: FileManager = .default) {
        self.manager = manager
    }

    // MARK: - Public
    public func exists(at path: String) -> Bool {
        manager.fileExists(atPath: path)
    }

    public func readData(at path: String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        return try Data(contentsOf: url)
    }

    public func writeData(_ data: Data, to path: String) throws {
        let url = URL(fileURLWithPath: path)
        try data.write(to: url)
    }

    public func delete(at path: String) throws {
        try manager.removeItem(atPath: path)
    }

    public func createDirectory(at path: String) throws {
        try manager.createDirectory(
            atPath: path,
            withIntermediateDirectories: true
        )
    }

    public func listContents(at path: String) throws -> [String] {
        try manager.contentsOfDirectory(atPath: path)
    }
}
