import Testing
import Foundation

@Suite("접근성 테스트")
struct AccessibilityTests {
    // MARK: - Property

    private let doc: HTMLDocument

    // MARK: - Initializer

    init() throws {
        doc = try HTMLDocument(contentsOf: TestConstants.htmlURL)
    }

    // MARK: - Public

    @Test("html 태그에 lang 속성이 존재한다")
    func htmlHasLangAttribute() {
        let pattern = "<html[^>]*\\blang=\"[^\"]+\"[^>]*>"
        #expect(doc.rawHTML.range(of: pattern, options: .regularExpression) != nil)
    }

    @Test("title 요소가 존재한다")
    func pageTitleExists() {
        #expect(doc.hasElement(tag: "title"))
        #expect(doc.rawHTML.contains("<title>"))
    }

    @Test("h1 제목이 존재한다")
    func h1HeadingExists() {
        #expect(doc.hasElement(tag: "h1"))
    }

    @Test("모든 상태 div에 role=status가 설정되어 있다")
    func allStatusDivsHaveRoleStatus() {
        for statusID in TestConstants.expectedStatusIDs {
            #expect(
                doc.hasAttribute("role", onElement: "div", withID: statusID),
                "상태 div '\(statusID)'에 role 속성이 있어야 한다"
            )
        }
    }

    @Test("모든 상태 div에 aria-live=polite가 설정되어 있다")
    func allStatusDivsHaveAriaLive() {
        for statusID in TestConstants.expectedStatusIDs {
            #expect(
                doc.hasAttribute("aria-live", onElement: "div", withID: statusID),
                "상태 div '\(statusID)'에 aria-live 속성이 있어야 한다"
            )
        }
    }

    @Test("체크박스에 연결된 label이 존재한다")
    func checkboxHasAssociatedLabel() {
        #expect(doc.rawHTML.contains("for=\"fileMultiple\""))
    }

    @Test("모든 텍스트 입력에 placeholder 속성이 존재한다")
    func allTextInputsHavePlaceholder() {
        // text input IDs that should have placeholder
        let textInputIDs = [
            "nameInput", "clipInput", "fileTypeFilter",
            "saveDefaultName", "fsPath", "shellUrl",
            "shellPath", "eventName"
        ]
        for inputID in textInputIDs {
            #expect(
                doc.hasAttribute("placeholder", onElement: "input", withID: inputID),
                "입력 '\(inputID)'에 placeholder 속성이 있어야 한다"
            )
        }
    }
}
