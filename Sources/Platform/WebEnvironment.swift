import Foundation

/// 환경 값의 주입 대상.
public enum EnvironmentType: Sendable {
    /// CSS 커스텀 프로퍼티. `:root`에 설정된다.
    case css

    /// JavaScript 변수. `window.__loom`에 설정된다.
    case variable
}

/// 웹 뷰에 주입할 환경 정보를 수집한다.
public struct WebEnvironment: Sendable {
    // MARK: - Property
    private var cssProperties: [String: String] = [:]
    private var variables: [String: String] = [:]

    /// 등록된 환경 값이 없는지 여부.
    public var isEmpty: Bool { cssProperties.isEmpty && variables.isEmpty }

    // MARK: - Initializer
    public init() {}

    // MARK: - Public
    /// 환경 값을 설정한다.
    public mutating func set(_ name: String, value: String, as type: EnvironmentType) {
        switch type {
        case .css:
            cssProperties[name] = value
        case .variable:
            variables[name] = value
        }
    }

    /// 등록된 모든 환경 값을 주입하는 JavaScript를 생성한다.
    public func injectionScript() -> String {
        var lines: [String] = []

        // CSS 커스텀 프로퍼티
        for (key, value) in cssProperties.sorted(by: { $0.key < $1.key }) {
            lines.append("document.documentElement.style.setProperty('\(key)', '\(value)');")
        }

        // JavaScript 변수
        if !variables.isEmpty {
            lines.append("window.__loom = window.__loom || {};")
            for (key, value) in variables.sorted(by: { $0.key < $1.key }) {
                let escaped = value
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                lines.append("window.__loom['\(key)'] = '\(escaped)';")
            }
        }

        guard !lines.isEmpty else { return "" }
        let body = lines.joined(separator: "\n    ")
        return "(function() {\n    \(body)\n})();"
    }
}
