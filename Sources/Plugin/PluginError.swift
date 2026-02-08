import Foundation

/// 플러그인 에러 열거형.
public enum PluginError: Error, Sendable, Equatable, LocalizedError {
    /// 잘못된 인자가 전달되었을 때.
    case invalidArguments

    /// 지원하지 않는 플랫폼에서 호출되었을 때.
    case unsupportedPlatform

    /// 플러그인이 초기화되지 않았을 때.
    case notInitialized

    /// 허용되지 않은 URL 스킴이 사용되었을 때.
    case blockedURLScheme(String)

    /// 허용되지 않은 경로에 접근하려 할 때.
    case blockedPath(String)

    /// JSON 인코딩에 실패했을 때.
    case encodingFailed

    /// 사용자 정의 에러.
    case custom(String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "플러그인 메서드에 잘못된 인자가 전달되었습니다."
        case .unsupportedPlatform:
            return "현재 플랫폼에서 지원하지 않는 기능입니다."
        case .notInitialized:
            return "플러그인이 초기화되지 않았습니다."
        case .blockedURLScheme(let scheme):
            return "허용되지 않은 URL 스킴입니다: \(scheme)"
        case .blockedPath(let path):
            return "허용되지 않은 경로입니다: \(path)"
        case .encodingFailed:
            return "JSON 인코딩에 실패했습니다."
        case .custom(let message):
            return message
        }
    }
}
