import Testing
import Foundation

@Suite("텍스트 오버플로우 테스트")
struct TextOverflowTests {
    // MARK: - Property

    private let css: CSSRuleSet

    // MARK: - Initializer

    init() throws {
        let doc = try HTMLDocument(contentsOf: TestConstants.htmlURL)
        let rawCSS = try #require(doc.extractEmbeddedCSS())
        css = CSSRuleSet(css: rawCSS)
    }

    // MARK: - Public

    @Test("status에 -webkit-line-clamp가 설정되어 있다")
    func statusHasLineClamp() {
        #expect(css.hasProperty("-webkit-line-clamp", inSelector: ".status"))
    }

    @Test("status에 word-break: break-word가 설정되어 있다")
    func statusHasWordBreak() {
        let value = css.getPropertyValue("word-break", inSelector: ".status")
        #expect(value == "break-word")
    }

    @Test("status에 overflow: hidden이 설정되어 있다")
    func statusHasOverflowHidden() {
        let value = css.getPropertyValue("overflow", inSelector: ".status")
        #expect(value == "hidden")
    }

    @Test("result-area에 overflow-y: auto가 설정되어 있다")
    func resultAreaHasOverflowY() {
        let value = css.getPropertyValue("overflow-y", inSelector: ".result-area")
        #expect(value == "auto")
    }

    @Test("result-area에 max-height가 설정되어 있다")
    func resultAreaHasMaxHeight() {
        #expect(css.hasProperty("max-height", inSelector: ".result-area"))
    }

    @Test("result-area에 word-break: break-word가 설정되어 있다")
    func resultAreaHasWordBreak() {
        let value = css.getPropertyValue("word-break", inSelector: ".result-area")
        #expect(value == "break-word")
    }

    @Test("event-log에 overflow-y와 max-height가 설정되어 있다")
    func eventLogHasOverflowAndMaxHeight() {
        #expect(css.hasProperty("overflow-y", inSelector: ".event-log"))
        #expect(css.hasProperty("max-height", inSelector: ".event-log"))
    }

    @Test("console에 overflow-y: auto가 설정되어 있다")
    func consoleHasOverflowY() {
        let value = css.getPropertyValue("overflow-y", inSelector: "#console")
        #expect(value == "auto")
    }

    @Test("console에 height 제약이 설정되어 있다")
    func consoleHasHeightConstraint() {
        #expect(css.hasProperty("height", inSelector: "#console"))
    }

    @Test("textarea에 resize: vertical이 설정되어 있다")
    func textareaHasResizeVertical() {
        let value = css.getPropertyValue("resize", inSelector: "textarea")
        #expect(value == "vertical")
    }

    @Test("button에 overflow: hidden과 text-overflow: ellipsis가 설정되어 있다")
    func buttonHasOverflowEllipsis() {
        let overflow = css.getPropertyValue("overflow", inSelector: "button")
        #expect(overflow == "hidden")
        let textOverflow = css.getPropertyValue("text-overflow", inSelector: "button")
        #expect(textOverflow == "ellipsis")
    }
}
