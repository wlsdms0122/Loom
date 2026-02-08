import Foundation

/// HTML 파일을 파싱하여 요소와 속성을 검증하는 헬퍼.
struct HTMLDocument: Sendable {
    // MARK: - Property

    let rawHTML: String

    // MARK: - Initializer

    init(contentsOf url: URL) throws {
        rawHTML = try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Public

    func hasElement(tag: String, withID id: String) -> Bool {
        let pattern = "<\(tag)[^>]*\\bid=\"\(NSRegularExpression.escapedPattern(for: id))\"[^>]*>"
        return rawHTML.range(of: pattern, options: .regularExpression) != nil
    }

    func hasElement(tag: String, withClass className: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: className)
        let pattern = "<\(tag)[^>]*\\bclass=\"[^\"]*\\b\(escaped)\\b[^\"]*\"[^>]*>"
        return rawHTML.range(of: pattern, options: .regularExpression) != nil
    }

    func hasElement(tag: String) -> Bool {
        return rawHTML.contains("<\(tag)")
    }

    func countElements(tag: String, withClass className: String? = nil) -> Int {
        if let className {
            let escaped = NSRegularExpression.escapedPattern(for: className)
            let pattern = "<\(tag)[^>]*\\bclass=\"[^\"]*\\b\(escaped)\\b[^\"]*\"[^>]*>"
            return matchCount(pattern: pattern)
        }
        let pattern = "<\(tag)[\\s>]"
        return matchCount(pattern: pattern)
    }

    func hasAttribute(_ attr: String, onElement tag: String, withID id: String) -> Bool {
        let idEscaped = NSRegularExpression.escapedPattern(for: id)
        let pattern = "<\(tag)[^>]*\\bid=\"\(idEscaped)\"[^>]*\\b\(attr)=\"[^\"]*\"[^>]*>"
        let pattern2 = "<\(tag)[^>]*\\b\(attr)=\"[^\"]*\"[^>]*\\bid=\"\(idEscaped)\"[^>]*>"
        return rawHTML.range(of: pattern, options: .regularExpression) != nil
            || rawHTML.range(of: pattern2, options: .regularExpression) != nil
    }

    func hasAttributeOnAny(attr: String, tag: String, value: String) -> Bool {
        let pattern = "<\(tag)[^>]*\\b\(attr)=\"\(NSRegularExpression.escapedPattern(for: value))\"[^>]*>"
        return rawHTML.range(of: pattern, options: .regularExpression) != nil
    }

    func extractEmbeddedCSS() -> String? {
        guard let styleStart = rawHTML.range(of: "<style>"),
              let styleEnd = rawHTML.range(of: "</style>") else { return nil }
        return String(rawHTML[styleStart.upperBound..<styleEnd.lowerBound])
    }

    // MARK: - Private

    private func matchCount(pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: rawHTML, range: NSRange(rawHTML.startIndex..., in: rawHTML))
    }
}
