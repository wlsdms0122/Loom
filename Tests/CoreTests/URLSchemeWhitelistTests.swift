import Foundation
import Testing
@testable import Core

@Suite("URLSchemeWhitelist 테스트")
struct URLSchemeWhitelistTests {
    // MARK: - Default Whitelist

    @Test("기본 화이트리스트가 http를 허용한다")
    func defaultAllowsHTTP() throws {
        let whitelist = URLSchemeWhitelist()
        let url = URL(string: "http://example.com")!
        #expect(throws: Never.self) {
            try whitelist.validate(url)
        }
    }

    @Test("기본 화이트리스트가 https를 허용한다")
    func defaultAllowsHTTPS() throws {
        let whitelist = URLSchemeWhitelist()
        let url = URL(string: "https://example.com")!
        #expect(throws: Never.self) {
            try whitelist.validate(url)
        }
    }

    @Test("기본 화이트리스트가 file 스킴을 차단한다")
    func defaultBlocksFile() {
        let whitelist = URLSchemeWhitelist()
        let url = URL(string: "file:///etc/passwd")!
        #expect(throws: URLSchemeWhitelist.WhitelistError.self) {
            try whitelist.validate(url)
        }
    }

    @Test("기본 화이트리스트가 javascript 스킴을 차단한다")
    func defaultBlocksJavascript() {
        let whitelist = URLSchemeWhitelist()
        let url = URL(string: "javascript:alert(1)")!
        #expect(throws: URLSchemeWhitelist.WhitelistError.self) {
            try whitelist.validate(url)
        }
    }

    @Test("기본 화이트리스트가 tel 스킴을 차단한다")
    func defaultBlocksTel() {
        let whitelist = URLSchemeWhitelist()
        let url = URL(string: "tel:+1234567890")!
        #expect(throws: URLSchemeWhitelist.WhitelistError.self) {
            try whitelist.validate(url)
        }
    }

    @Test("기본 화이트리스트가 커스텀 스킴을 차단한다")
    func defaultBlocksCustomScheme() {
        let whitelist = URLSchemeWhitelist()
        let url = URL(string: "myapp://deeplink")!
        #expect(throws: URLSchemeWhitelist.WhitelistError.self) {
            try whitelist.validate(url)
        }
    }

    // MARK: - Custom Whitelist

    @Test("커스텀 화이트리스트가 지정된 스킴을 허용한다")
    func customAllowsSpecifiedSchemes() throws {
        let whitelist = URLSchemeWhitelist(schemes: ["http", "https", "myapp"])
        let url = URL(string: "myapp://deeplink")!
        #expect(throws: Never.self) {
            try whitelist.validate(url)
        }
    }

    @Test("커스텀 화이트리스트가 지정되지 않은 스킴을 차단한다")
    func customBlocksUnspecifiedSchemes() {
        let whitelist = URLSchemeWhitelist(schemes: ["myapp"])
        let url = URL(string: "https://example.com")!
        #expect(throws: URLSchemeWhitelist.WhitelistError.self) {
            try whitelist.validate(url)
        }
    }

    @Test("스킴 비교가 대소문자를 구분하지 않는다")
    func caseInsensitiveSchemeComparison() throws {
        let whitelist = URLSchemeWhitelist(schemes: ["HTTP", "HTTPS"])
        let url = URL(string: "https://example.com")!
        #expect(throws: Never.self) {
            try whitelist.validate(url)
        }
    }

    // MARK: - Error Details

    @Test("차단된 스킴 에러에 스킴 이름이 포함된다")
    func errorContainsSchemeName() {
        let whitelist = URLSchemeWhitelist()
        let url = URL(string: "ftp://files.example.com")!
        #expect {
            try whitelist.validate(url)
        } throws: { error in
            guard let whitelistError = error as? URLSchemeWhitelist.WhitelistError else {
                return false
            }
            return whitelistError == .schemeNotAllowed("ftp")
        }
    }
}
