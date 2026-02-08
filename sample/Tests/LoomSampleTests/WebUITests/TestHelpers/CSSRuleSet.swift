import Foundation

/// CSS 문자열을 분석하여 규칙과 속성을 검증하는 헬퍼.
struct CSSRuleSet: Sendable {
    // MARK: - Property

    let rawCSS: String

    // MARK: - Initializer

    init(css: String) {
        rawCSS = css
    }

    // MARK: - Public

    func hasRule(selector: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: selector)
        let pattern = "(^|[},;\\s])\(escaped)\\s*\\{"
        return rawCSS.range(of: pattern, options: .regularExpression) != nil
    }

    func hasProperty(_ property: String, inSelector selector: String) -> Bool {
        return getPropertyValue(property, inSelector: selector) != nil
    }

    func getPropertyValue(_ property: String, inSelector selector: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: selector)
        let rulePattern = "\(escaped)\\s*\\{([^}]*)\\}"
        guard let regex = try? NSRegularExpression(pattern: rulePattern),
              let match = regex.firstMatch(in: rawCSS, range: NSRange(rawCSS.startIndex..., in: rawCSS)),
              let blockRange = Range(match.range(at: 1), in: rawCSS) else { return nil }

        let block = String(rawCSS[blockRange])
        let propPattern = "\(NSRegularExpression.escapedPattern(for: property))\\s*:\\s*([^;]+)"
        guard let propRegex = try? NSRegularExpression(pattern: propPattern),
              let propMatch = propRegex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
              let valueRange = Range(propMatch.range(at: 1), in: block) else { return nil }

        return block[valueRange].trimmingCharacters(in: .whitespaces)
    }

    func hasCSSVariable(_ variable: String) -> Bool {
        let pattern = "\(NSRegularExpression.escapedPattern(for: variable))\\s*:"
        return rawCSS.range(of: pattern, options: .regularExpression) != nil
    }

    func hasMediaQuery(_ query: String) -> Bool {
        return rawCSS.contains(query)
    }
}
