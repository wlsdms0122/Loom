import Testing
import Foundation
@testable import Core

@Suite("PathSandbox Tests")
struct PathSandboxTests {
    // MARK: - Property

    private let tempDir: String
    private let sandbox: PathSandbox

    // MARK: - Initializer

    init() throws {
        let dir = NSTemporaryDirectory() + "LoomSandboxTests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: dir,
            withIntermediateDirectories: true
        )
        // Resolve the temp directory through realpath so comparisons work on macOS
        // where /tmp is a symlink to /private/tmp.
        if let resolved = realpath(dir, nil) {
            tempDir = String(cString: resolved)
            free(resolved)
        } else {
            tempDir = dir
        }
        sandbox = PathSandbox(allowedDirectories: [tempDir])
    }

    // MARK: - Path Traversal Tests

    @Test("Path traversal with .. is blocked")
    func pathTraversalBlocked() throws {
        let maliciousPath = tempDir + "/../../etc/passwd"
        #expect(throws: PathSandbox.SandboxError.self) {
            _ = try sandbox.validatePath(maliciousPath)
        }
    }

    @Test("Absolute path outside sandbox is blocked")
    func absolutePathOutsideSandbox() {
        #expect(throws: PathSandbox.SandboxError.self) {
            _ = try sandbox.validatePath("/etc/passwd")
        }
    }

    @Test("Path under allowed directory succeeds")
    func allowedPathSucceeds() throws {
        let filePath = tempDir + "/allowed.txt"
        try Data("test".utf8).write(to: URL(fileURLWithPath: filePath))

        let result = try sandbox.validatePath(filePath)
        #expect(result.filePath == filePath)

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("Path to new file under allowed directory succeeds")
    func newFileUnderAllowedDirectorySucceeds() throws {
        let filePath = tempDir + "/newfile.txt"
        let result = try sandbox.validatePath(filePath)
        #expect(result.filePath == filePath)

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("Symlink resolution detects escape")
    func symlinkResolutionDetectsEscape() throws {
        // Create a symlink inside the sandbox that points outside it.
        let linkPath = tempDir + "/escape_link"
        try FileManager.default.createSymbolicLink(
            atPath: linkPath,
            withDestinationPath: "/etc"
        )

        let targetPath = linkPath + "/passwd"
        #expect(throws: PathSandbox.SandboxError.self) {
            _ = try sandbox.validatePath(targetPath)
        }

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    @Test("Denied path throws pathNotAllowed error")
    func deniedPathThrowsAppropriateError() {
        do {
            _ = try sandbox.validatePath("/usr/bin/ls")
            Issue.record("Expected SandboxError.pathNotAllowed but no error was thrown")
        } catch let error as PathSandbox.SandboxError {
            if case .pathNotAllowed = error {
                // Expected
            } else {
                Issue.record("Expected SandboxError.pathNotAllowed but got \(error)")
            }
        } catch {
            Issue.record("Expected SandboxError but got \(error)")
        }
    }

    @Test("Invalid path with unresolvable parent throws invalidPath error")
    func invalidPathThrows() {
        let sandbox = PathSandbox(allowedDirectories: ["/nonexistent_sandbox_dir"])
        #expect(throws: PathSandbox.SandboxError.self) {
            _ = try sandbox.validatePath("/nonexistent_sandbox_dir/subdir/file.txt")
        }
    }

    // MARK: - Multiple Allowed Directories

    @Test("Multiple allowed directories are all accessible")
    func multipleAllowedDirectories() throws {
        let dir2 = NSTemporaryDirectory() + "LoomSandboxTests2-\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: dir2,
            withIntermediateDirectories: true
        )

        let resolvedDir2: String
        if let resolved = realpath(dir2, nil) {
            resolvedDir2 = String(cString: resolved)
            free(resolved)
        } else {
            resolvedDir2 = dir2
        }

        let multiSandbox = PathSandbox(allowedDirectories: [tempDir, resolvedDir2])

        let file1 = tempDir + "/file1.txt"
        let file2 = resolvedDir2 + "/file2.txt"
        try Data("a".utf8).write(to: URL(fileURLWithPath: file1))
        try Data("b".utf8).write(to: URL(fileURLWithPath: file2))

        let result1 = try multiSandbox.validatePath(file1)
        #expect(result1.filePath == file1)

        let result2 = try multiSandbox.validatePath(file2)
        #expect(result2.filePath == file2)

        // Cleanup
        try? FileManager.default.removeItem(atPath: tempDir)
        try? FileManager.default.removeItem(atPath: dir2)
    }
}
