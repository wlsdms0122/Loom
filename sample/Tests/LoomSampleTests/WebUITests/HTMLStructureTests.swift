import Testing
import Foundation

@Suite("HTML 구조 테스트")
struct HTMLStructureTests {
    // MARK: - Property

    private let doc: HTMLDocument

    // MARK: - Initializer

    init() throws {
        doc = try HTMLDocument(contentsOf: TestConstants.htmlURL)
    }

    // MARK: - Public

    @Test("DOCTYPE 선언이 존재한다")
    func hasDOCTYPE() {
        #expect(doc.rawHTML.hasPrefix("<!DOCTYPE html>"))
    }

    @Test("html 태그에 lang 속성이 en으로 설정되어 있다")
    func htmlHasLangAttribute() {
        let pattern = "<html[^>]*\\blang=\"en\"[^>]*>"
        #expect(doc.rawHTML.range(of: pattern, options: .regularExpression) != nil)
    }

    @Test("header 섹션이 존재한다")
    func headerExists() {
        #expect(doc.hasElement(tag: "header"))
    }

    @Test("header에 h1 제목이 존재한다")
    func headerHasH1() {
        #expect(doc.hasElement(tag: "h1"))
        #expect(doc.rawHTML.contains("<h1>Loom Sample</h1>"))
    }

    @Test("header에 p 설명이 존재한다")
    func headerHasDescription() {
        #expect(doc.hasElement(tag: "p"))
        #expect(doc.rawHTML.contains("Modern Web-to-Native Bridge Testbed"))
    }

    @Test("container div가 존재한다")
    func containerExists() {
        #expect(doc.hasElement(tag: "div", withClass: "container"))
    }

    @Test("grid div가 존재한다")
    func gridExists() {
        #expect(doc.hasElement(tag: "div", withClass: "grid"))
    }

    @Test("카드가 총 11개 존재한다 (기능 10개 + 콘솔 1개)")
    func totalCardCount() {
        let cardCount = doc.countElements(tag: "div", withClass: "card")
        #expect(cardCount == 11)
    }

    @Test("console-card 클래스를 가진 카드가 존재한다")
    func consoleCardExists() {
        #expect(doc.hasElement(tag: "div", withClass: "console-card"))
    }

    @Test("모든 입력 요소 ID가 존재한다")
    func allInputIDsExist() {
        for inputID in TestConstants.expectedInputIDs {
            #expect(
                doc.rawHTML.contains("id=\"\(inputID)\""),
                "입력 요소 '\(inputID)'가 존재해야 한다"
            )
        }
    }

    @Test("모든 상태 div ID가 존재한다")
    func allStatusIDsExist() {
        for statusID in TestConstants.expectedStatusIDs {
            #expect(
                doc.hasElement(tag: "div", withID: statusID),
                "상태 div '\(statusID)'가 존재해야 한다"
            )
        }
    }

    @Test("console 요소가 존재한다")
    func consoleElementExists() {
        #expect(doc.hasElement(tag: "div", withID: "console"))
    }

    @Test("test-all-btn 버튼이 존재한다")
    func testAllButtonExists() {
        #expect(doc.hasElement(tag: "button", withClass: "test-all-btn"))
    }

    @Test("카드 h2 제목이 9개 이상 존재한다")
    func cardH2Count() {
        let h2Count = doc.countElements(tag: "h2")
        // 9 feature cards + 1 console card = 10 h2 headings
        #expect(h2Count >= 10)
    }

    @Test("모든 카드 제목 텍스트가 포함되어 있다")
    func allCardTitlesExist() {
        for title in TestConstants.expectedCardTitles {
            #expect(
                doc.rawHTML.contains("<h2>\(title)</h2>"),
                "카드 제목 '\(title)'이 존재해야 한다"
            )
        }
    }
}
