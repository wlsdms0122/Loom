import Foundation
import Testing
@testable import PlatformMacOS

/// MacOSFileSystem의 기본 파일 작업을 검증한다.
@Suite("MacOSFileSystem")
struct MacOSFileSystemTests {
    // MARK: - Property
    private let fs: MacOSFileSystem
    private let testDir: String

    // MARK: - Initializer
    init() throws {
        fs = MacOSFileSystem()
        testDir = NSTemporaryDirectory() + "LoomFileSystemTests_\(UUID().uuidString)"
        try fs.createDirectory(at: testDir)
    }

    // MARK: - Public
    @Test("파일이 존재하지 않으면 false를 반환한다")
    func existsReturnsFalse() {
        let exists = fs.exists(at: testDir + "/nonexistent.txt")
        #expect(exists == false)
    }

    @Test("파일을 쓰고 존재를 확인할 수 있다")
    func writeAndExists() throws {
        let path = testDir + "/test.txt"
        let data = Data("hello".utf8)
        try fs.writeData(data, to: path)

        #expect(fs.exists(at: path))
    }

    @Test("파일을 쓰고 읽을 수 있다")
    func writeAndRead() throws {
        let path = testDir + "/readwrite.txt"
        let content = "Loom framework"
        let data = Data(content.utf8)
        try fs.writeData(data, to: path)

        let readData = try fs.readData(at: path)
        let readContent = String(data: readData, encoding: .utf8)

        #expect(readContent == content)
    }

    @Test("파일을 삭제할 수 있다")
    func deleteFile() throws {
        let path = testDir + "/delete.txt"
        try fs.writeData(Data("temp".utf8), to: path)
        #expect(fs.exists(at: path))

        try fs.delete(at: path)
        #expect(!fs.exists(at: path))
    }

    @Test("디렉터리 내 항목을 나열할 수 있다")
    func listContents() throws {
        let file1 = testDir + "/a.txt"
        let file2 = testDir + "/b.txt"
        try fs.writeData(Data("a".utf8), to: file1)
        try fs.writeData(Data("b".utf8), to: file2)

        let contents = try fs.listContents(at: testDir)
        #expect(contents.contains("a.txt"))
        #expect(contents.contains("b.txt"))
    }

    @Test("디렉터리를 생성할 수 있다")
    func createDirectory() throws {
        let dirPath = testDir + "/subdir/nested"
        try fs.createDirectory(at: dirPath)

        #expect(fs.exists(at: dirPath))
    }
}
