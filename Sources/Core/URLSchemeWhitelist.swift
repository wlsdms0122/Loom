import Foundation

/// URL 스킴 화이트리스트. 허용된 스킴만 통과시킨다.
public struct URLSchemeWhitelist: Sendable {
    // MARK: - Property

    /// 허용된 URL 스킴이 아닌 경우 발생하는 에러.
    public enum WhitelistError: Error, Sendable, Equatable, LocalizedError {
        /// URL 스킴이 화이트리스트에 포함되지 않을 때.
        case schemeNotAllowed(String)

        // MARK: - LocalizedError

        public var errorDescription: String? {
            switch self {
            case .schemeNotAllowed(let scheme):
                return "허용되지 않은 URL 스킴입니다: \(scheme)"
            }
        }
    }

    private let allowedSchemes: Set<String>

    // MARK: - Initializer

    /// 허용할 URL 스킴 목록으로 화이트리스트를 생성한다.
    /// - Parameter schemes: 허용할 스킴 목록. 기본값은 `["http", "https"]`.
    public init(schemes: [String] = ["http", "https"]) {
        self.allowedSchemes = Set(schemes.map { $0.lowercased() })
    }

    // MARK: - Public

    /// URL의 스킴이 화이트리스트에 포함되어 있는지 검증한다.
    /// - Parameter url: 검증할 URL.
    /// - Throws: 스킴이 허용되지 않으면 `WhitelistError.schemeNotAllowed`를 던진다.
    public func validate(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased(), allowedSchemes.contains(scheme) else {
            throw WhitelistError.schemeNotAllowed(url.scheme ?? "none")
        }
    }
}
