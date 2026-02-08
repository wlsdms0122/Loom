import Foundation

/// LoomApp 관련 에러.
public enum LoomAppError: Error, Sendable, Equatable, LocalizedError {
    /// 앱이 아직 실행되지 않은 상태에서 호출되었을 때.
    case notRunning

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return "LoomApp이 아직 실행되지 않았습니다. run()을 먼저 호출하세요."
        }
    }
}
