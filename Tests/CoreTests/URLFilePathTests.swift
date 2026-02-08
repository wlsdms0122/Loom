import Foundation
import Testing
@testable import Core

/// URL.filePath 확장의 경로 정규화를 검증한다.
@Suite("URL.filePath")
struct URLFilePathTests {
    @Test("일반 파일 경로의 후행 슬래시가 제거된다")
    func trailingSlashRemoved() {
        let url = URL(fileURLWithPath: "/Users/test/Documents/")
        #expect(url.filePath == "/Users/test/Documents")
    }

    @Test("후행 슬래시 없는 경로는 그대로 반환된다")
    func noTrailingSlash() {
        let url = URL(fileURLWithPath: "/Users/test/file.txt")
        #expect(url.filePath == "/Users/test/file.txt")
    }

    @Test("루트 경로 /는 그대로 유지된다")
    func rootPathPreserved() {
        let url = URL(fileURLWithPath: "/")
        #expect(url.filePath == "/")
    }

    @Test("공백이 포함된 경로가 디코딩된다")
    func pathWithSpacesDecoded() {
        let url = URL(fileURLWithPath: "/Users/test/My Documents/file.txt")
        #expect(url.filePath == "/Users/test/My Documents/file.txt")
    }

    @Test("한글 경로가 디코딩된다")
    func koreanPathDecoded() {
        let url = URL(fileURLWithPath: "/Users/test/문서/파일.txt")
        #expect(url.filePath == "/Users/test/문서/파일.txt")
    }
}
