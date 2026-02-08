import Foundation
import Core
import Platform

/// 파일 시스템 플러그인. 파일 읽기, 쓰기, 존재 확인, 디렉토리 조회, 삭제 기능을 제공한다.
public struct FileSystemPlugin: Plugin, Sendable {
    // MARK: - Property

    public let name = "filesystem"
    private let securityPolicy: any SecurityPolicy
    private let fileSystemStorage: PlatformServiceStorage<any FileSystem>

    // MARK: - Initializer

    @available(*, unavailable, message: "SecurityPolicy is required. Use init(securityPolicy:) instead.")
    public init() {
        fatalError("SecurityPolicy is required")
    }

    public init(securityPolicy: any SecurityPolicy) {
        self.securityPolicy = securityPolicy
        self.fileSystemStorage = PlatformServiceStorage()
    }

    // MARK: - Public

    public func initialize(context: any PluginContext) async throws {
        if let fs = await context.container.resolve((any FileSystem).self) {
            fileSystemStorage.update(fs)
        }
    }

    /// 파일 시스템 메서드를 반환한다.
    ///
    /// 플랫폼 `FileSystem` 서비스가 없으면 `FileManager.default`로 폴백한다.
    /// 다른 플러그인(Clipboard, Dialog 등)은 서비스 부재 시 `unsupportedPlatform`을 던지지만,
    /// 파일 시스템은 Foundation 수준에서 항상 가용하므로 폴백이 합리적이다.
    /// `SecurityPolicy` 검증은 폴백 경로에서도 동일하게 적용된다.
    public func methods() async -> [PluginMethod] {
        let storage = fileSystemStorage
        return [
            PluginMethod(name: "readFile") { (args: PathArgs) -> ReadFileResult in
                let path = try validatedPath(args.path).filePath
                let fileData: Data
                if let fs = storage.current {
                    fileData = try fs.readData(at: path)
                } else {
                    fileData = try Data(contentsOf: URL(fileURLWithPath: path))
                }
                return ReadFileResult(content: fileData.base64EncodedString())
            },
            PluginMethod(name: "writeFile") { (args: WriteFileArgs) in
                let content: Data
                if let base64Data = Data(base64Encoded: args.content) {
                    content = base64Data
                } else {
                    content = Data(args.content.utf8)
                }
                let path = try validatedPath(args.path).filePath
                if let fs = storage.current {
                    try fs.writeData(content, to: path)
                } else {
                    try content.write(to: URL(fileURLWithPath: path))
                }
            },
            PluginMethod(name: "exists") { (args: PathArgs) -> [String: Bool] in
                let path = try validatedPath(args.path).filePath
                let exists: Bool
                if let fs = storage.current {
                    exists = fs.exists(at: path)
                } else {
                    exists = FileManager.default.fileExists(atPath: path)
                }
                return ["exists": exists]
            },
            PluginMethod(name: "readDir") { (args: PathArgs) -> [String: [String]] in
                let path = try validatedPath(args.path).filePath
                let items: [String]
                if let fs = storage.current {
                    items = try fs.listContents(at: path)
                } else {
                    items = try FileManager.default.contentsOfDirectory(atPath: path)
                }
                return ["entries": items]
            },
            PluginMethod(name: "remove") { (args: PathArgs) in
                let path = try validatedPath(args.path).filePath
                if let fs = storage.current {
                    try fs.delete(at: path)
                } else {
                    try FileManager.default.removeItem(atPath: path)
                }
            }
        ]
    }

    // MARK: - Private

    private func validatedPath(_ path: String) throws -> URL {
        try securityPolicy.validatePath(path)
    }
}

// MARK: - Argument Types

/// 파일 쓰기 인자.
private struct WriteFileArgs: Codable, Sendable {
    let path: String
    let content: String
}

/// 파일 읽기 결과.
private struct ReadFileResult: Codable, Sendable {
    let content: String
}
