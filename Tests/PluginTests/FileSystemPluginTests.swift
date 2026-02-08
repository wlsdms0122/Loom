import Testing
import Foundation
@testable import Plugin
@testable import Core

@Suite("FileSystemPlugin 테스트")
struct FileSystemPluginTests {
    // MARK: - Property

    private let plugin: FileSystemPlugin
    private let tempDir: String

    // MARK: - Initializer

    init() throws {
        let dir = NSTemporaryDirectory() + "LoomFSPluginTests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )
        // Resolve symlinks for macOS /tmp -> /private/tmp.
        if let resolved = realpath(dir, nil) {
            tempDir = String(cString: resolved)
            free(resolved)
        } else {
            tempDir = dir
        }
        let sandbox = PathSandbox(allowedDirectories: [tempDir])
        plugin = FileSystemPlugin(securityPolicy: sandbox)
    }

    // MARK: - Tests

    @Test("플러그인 이름이 filesystem이다")
    func name() {
        #expect(plugin.name == "filesystem")
    }

    @Test("파일을 쓰고 읽을 수 있다")
    func writeAndReadFile() async throws {
        let filePath = tempDir + "/test.txt"
        let content = "Hello, Loom!"
        let base64Content = Data(content.utf8).base64EncodedString()

        let writePayload = """
        {"path":"\(filePath)","content":"\(base64Content)"}
        """

        let methods = await plugin.methods()
        let writeMethod = try #require(methods.first { $0.name == "writeFile" })
        let readMethod = try #require(methods.first { $0.name == "readFile" })

        _ = try await writeMethod.handler(writePayload)

        let readPayload = """
        {"path":"\(filePath)"}
        """
        let readResult = try await readMethod.handler(readPayload)
        let decoded = try JSONDecoder().decode(
            [String: String].self,
            from: Data(readResult.utf8)
        )

        let resultData = try #require(Data(base64Encoded: decoded["content"] ?? ""))
        let resultString = String(data: resultData, encoding: .utf8)
        #expect(resultString == "Hello, Loom!")

        // 정리
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("파일 존재 여부를 확인할 수 있다")
    func exists() async throws {
        let filePath = tempDir + "/exists_test.txt"
        try Data("test".utf8).write(to: URL(fileURLWithPath: filePath))

        let methods = await plugin.methods()
        let existsMethod = try #require(methods.first { $0.name == "exists" })

        let payload = """
        {"path":"\(filePath)"}
        """
        let result = try await existsMethod.handler(payload)
        let decoded = try JSONDecoder().decode(
            [String: Bool].self,
            from: Data(result.utf8)
        )
        #expect(decoded["exists"] == true)

        let missingPayload = """
        {"path":"\(tempDir)/missing.txt"}
        """
        let missingResult = try await existsMethod.handler(missingPayload)
        let missingDecoded = try JSONDecoder().decode(
            [String: Bool].self,
            from: Data(missingResult.utf8)
        )
        #expect(missingDecoded["exists"] == false)

        // 정리
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("디렉토리 내용을 조회할 수 있다")
    func readDir() async throws {
        try Data("a".utf8).write(to: URL(fileURLWithPath: tempDir + "/file1.txt"))
        try Data("b".utf8).write(to: URL(fileURLWithPath: tempDir + "/file2.txt"))

        let methods = await plugin.methods()
        let readDirMethod = try #require(methods.first { $0.name == "readDir" })

        let payload = """
        {"path":"\(tempDir)"}
        """
        let result = try await readDirMethod.handler(payload)
        let decoded = try JSONDecoder().decode(
            [String: [String]].self,
            from: Data(result.utf8)
        )
        let entries = try #require(decoded["entries"])
        #expect(entries.contains("file1.txt"))
        #expect(entries.contains("file2.txt"))

        // 정리
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("파일을 삭제할 수 있다")
    func removeFile() async throws {
        let filePath = tempDir + "/to_delete.txt"
        try Data("delete me".utf8).write(to: URL(fileURLWithPath: filePath))
        #expect(FileManager.default.fileExists(atPath: filePath))

        let methods = await plugin.methods()
        let removeMethod = try #require(methods.first { $0.name == "remove" })

        let payload = """
        {"path":"\(filePath)"}
        """
        _ = try await removeMethod.handler(payload)
        #expect(!FileManager.default.fileExists(atPath: filePath))

        // 정리
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("UTF-8 텍스트를 직접 쓸 수 있다")
    func writeUtf8Content() async throws {
        let filePath = tempDir + "/utf8.txt"
        let content = "plain text content"

        let writePayload = """
        {"path":"\(filePath)","content":"\(content)"}
        """

        let methods = await plugin.methods()
        let writeMethod = try #require(methods.first { $0.name == "writeFile" })
        _ = try await writeMethod.handler(writePayload)

        let written = try String(contentsOfFile: filePath, encoding: .utf8)
        #expect(written == content)

        // 정리
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("존재하지 않는 파일을 읽으면 에러가 발생한다")
    func readFileNonexistentPathThrows() async throws {
        let methods = await plugin.methods()
        let readMethod = try #require(methods.first { $0.name == "readFile" })

        let payload = """
        {"path":"\(tempDir)/nonexistent_file.txt"}
        """
        await #expect(throws: (any Error).self) {
            _ = try await readMethod.handler(payload)
        }

        // 정리
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("존재하지 않는 디렉토리를 조회하면 에러가 발생한다")
    func readDirNonexistentPathThrows() async throws {
        let methods = await plugin.methods()
        let readDirMethod = try #require(methods.first { $0.name == "readDir" })

        let payload = """
        {"path":"\(tempDir)/nonexistent_directory"}
        """
        await #expect(throws: (any Error).self) {
            _ = try await readDirMethod.handler(payload)
        }

        // 정리
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("허용되지 않은 경로에 파일을 쓰면 SandboxError가 발생한다")
    func writeFileToDeniedPathThrows() async throws {
        let methods = await plugin.methods()
        let writeMethod = try #require(methods.first { $0.name == "writeFile" })

        let payload = """
        {"path":"/etc/evil.txt","content":"data"}
        """
        await #expect(throws: PathSandbox.SandboxError.self) {
            _ = try await writeMethod.handler(payload)
        }
    }

    @Test("잘못된 JSON 페이로드를 전달하면 디코딩 에러가 발생한다")
    func invalidJSONPayloadThrows() async throws {
        let methods = await plugin.methods()
        let readMethod = try #require(methods.first { $0.name == "readFile" })

        let invalidPayload = "this is not valid json"
        await #expect(throws: (any Error).self) {
            _ = try await readMethod.handler(invalidPayload)
        }
    }

    @Test("필수 필드가 누락된 JSON 페이로드를 전달하면 디코딩 에러가 발생한다")
    func missingFieldJSONPayloadThrows() async throws {
        let methods = await plugin.methods()
        let writeMethod = try #require(methods.first { $0.name == "writeFile" })

        // writeFile requires "path" and "content", only providing "path"
        let payload = """
        {"path":"/tmp/test.txt"}
        """
        await #expect(throws: (any Error).self) {
            _ = try await writeMethod.handler(payload)
        }
    }
}

// MARK: - Sandbox Tests

@Suite("FileSystemPlugin Sandbox 테스트")
struct FileSystemPluginSandboxTests {
    // MARK: - Property

    private let sandboxedPlugin: FileSystemPlugin
    private let tempDir: String

    // MARK: - Initializer

    init() throws {
        let dir = NSTemporaryDirectory() + "LoomFSSandboxTests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )
        // Resolve symlinks for macOS /tmp -> /private/tmp.
        if let resolved = realpath(dir, nil) {
            tempDir = String(cString: resolved)
            free(resolved)
        } else {
            tempDir = dir
        }
        let sandbox = PathSandbox(allowedDirectories: [tempDir])
        sandboxedPlugin = FileSystemPlugin(securityPolicy: sandbox)
    }

    // MARK: - Tests

    @Test("readFile throws when path is outside sandbox")
    func readFileOutsideSandbox() async throws {
        let methods = await sandboxedPlugin.methods()
        let readMethod = try #require(methods.first { $0.name == "readFile" })

        let payload = """
        {"path":"/etc/passwd"}
        """
        await #expect(throws: PathSandbox.SandboxError.self) {
            _ = try await readMethod.handler(payload)
        }
    }

    @Test("remove throws when path is root")
    func removeRootBlocked() async throws {
        let methods = await sandboxedPlugin.methods()
        let removeMethod = try #require(methods.first { $0.name == "remove" })

        let payload = """
        {"path":"/"}
        """
        await #expect(throws: PathSandbox.SandboxError.self) {
            _ = try await removeMethod.handler(payload)
        }
    }

    @Test("writeFile throws when path is outside sandbox")
    func writeFileOutsideSandbox() async throws {
        let methods = await sandboxedPlugin.methods()
        let writeMethod = try #require(methods.first { $0.name == "writeFile" })

        let payload = """
        {"path":"/etc/evil.txt","content":"malicious"}
        """
        await #expect(throws: PathSandbox.SandboxError.self) {
            _ = try await writeMethod.handler(payload)
        }
    }

    @Test("exists throws when path is outside sandbox")
    func existsOutsideSandbox() async throws {
        let methods = await sandboxedPlugin.methods()
        let existsMethod = try #require(methods.first { $0.name == "exists" })

        let payload = """
        {"path":"/etc/passwd"}
        """
        await #expect(throws: PathSandbox.SandboxError.self) {
            _ = try await existsMethod.handler(payload)
        }
    }

    @Test("readDir throws when path is outside sandbox")
    func readDirOutsideSandbox() async throws {
        let methods = await sandboxedPlugin.methods()
        let readDirMethod = try #require(methods.first { $0.name == "readDir" })

        let payload = """
        {"path":"/etc"}
        """
        await #expect(throws: PathSandbox.SandboxError.self) {
            _ = try await readDirMethod.handler(payload)
        }
    }

    @Test("Paths under sandbox directory are accessible")
    func pathsUnderSandboxAccessible() async throws {
        let filePath = tempDir + "/sandbox_test.txt"
        try Data("sandboxed content".utf8).write(to: URL(fileURLWithPath: filePath))

        let methods = await sandboxedPlugin.methods()
        let readMethod = try #require(methods.first { $0.name == "readFile" })

        let payload = """
        {"path":"\(filePath)"}
        """
        let result = try await readMethod.handler(payload)
        let decoded = try JSONDecoder().decode(
            [String: String].self,
            from: Data(result.utf8)
        )
        #expect(decoded["content"] != nil)

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("허용되지 않은 경로 접근 시 pathNotAllowed 에러를 반환한다")
    func deniedPathReturnsPathNotAllowedError() async throws {
        let methods = await sandboxedPlugin.methods()
        let readMethod = try #require(methods.first { $0.name == "readFile" })

        let payload = """
        {"path":"/usr/local/secret.txt"}
        """
        await #expect(throws: PathSandbox.SandboxError.self) {
            _ = try await readMethod.handler(payload)
        }
    }
}
