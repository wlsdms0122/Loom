import Testing
import Foundation

@Suite("CSS 규칙 테스트")
struct CSSRuleTests {
    // MARK: - Property

    private let css: CSSRuleSet

    // MARK: - Initializer

    init() throws {
        let doc = try HTMLDocument(contentsOf: TestConstants.htmlURL)
        let rawCSS = try #require(doc.extractEmbeddedCSS())
        css = CSSRuleSet(css: rawCSS)
    }

    // MARK: - Public

    @Test("모든 CSS 변수가 :root에 정의되어 있다")
    func allCSSVariablesDefined() {
        for variable in TestConstants.requiredCSSVariables {
            #expect(
                css.hasCSSVariable(variable),
                "CSS 변수 '\(variable)'가 :root에 정의되어야 한다"
            )
        }
    }

    @Test("다크 모드 미디어 쿼리가 존재한다")
    func darkModeMediaQueryExists() {
        #expect(css.hasMediaQuery("prefers-color-scheme: dark"))
    }

    @Test("body에 display: flex가 설정되어 있다")
    func bodyHasDisplayFlex() {
        let value = css.getPropertyValue("display", inSelector: "body")
        #expect(value == "flex")
    }

    @Test("grid에 display: grid가 설정되어 있다")
    func gridHasDisplayGrid() {
        let value = css.getPropertyValue("display", inSelector: ".grid")
        #expect(value == "grid")
    }

    @Test("grid에 repeat(2, 1fr) 컬럼이 설정되어 있다")
    func gridHasTwoColumnLayout() {
        let value = css.getPropertyValue("grid-template-columns", inSelector: ".grid")
        #expect(value == "repeat(2, 1fr)")
    }

    @Test("card에 backdrop-filter가 설정되어 있다")
    func cardHasBackdropFilter() {
        #expect(css.hasProperty("backdrop-filter", inSelector: ".card"))
    }

    @Test("card에 border-radius가 설정되어 있다")
    func cardHasBorderRadius() {
        #expect(css.hasProperty("border-radius", inSelector: ".card"))
    }

    @Test("button에 기본 스타일이 설정되어 있다")
    func buttonHasBaseStyles() {
        #expect(css.hasProperty("padding", inSelector: "button"))
        #expect(css.hasProperty("border-radius", inSelector: "button"))
        #expect(css.hasProperty("background", inSelector: "button"))
        #expect(css.hasProperty("color", inSelector: "button"))
    }

    @Test("secondary 버튼 변형이 존재한다")
    func secondaryButtonVariantExists() {
        #expect(css.hasRule(selector: "button.secondary"))
    }

    @Test("destructive 버튼 변형이 존재한다")
    func destructiveButtonVariantExists() {
        #expect(css.hasRule(selector: "button.destructive"))
    }

    @Test("card hover에 box-shadow만 적용되고 transform은 없다")
    func cardHoverHasShadowOnly() {
        #expect(css.hasProperty("box-shadow", inSelector: ".card:hover"))
        let transform = css.getPropertyValue("transform", inSelector: ".card:hover")
        #expect(transform == nil, "card hover에 transform이 없어야 한다")
    }
}
