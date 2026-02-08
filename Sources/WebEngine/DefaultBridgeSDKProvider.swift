import Foundation

// MARK: - BridgeSDKError

/// Bridge SDK 관련 에러.
public enum BridgeSDKError: Error, Sendable, Equatable, LocalizedError {
    /// Bridge SDK 리소스를 찾을 수 없거나 읽을 수 없을 때.
    case sdkResourceNotAvailable(bundlePath: String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case let .sdkResourceNotAvailable(bundlePath):
            return """
            bridge-sdk.js를 번들 리소스에서 찾을 수 없거나 읽을 수 없음
            - Bundle 경로: \(bundlePath)
            - 확인 사항:
              1. WebEngine 모듈의 Resources에 bridge-sdk.js가 포함되어 있는지 확인하세요.
              2. Package.swift에서 .process("Resources") 또는 .copy("Resources")가 설정되어 있는지 확인하세요.
            """
        }
    }
}

/// Bridge JS SDK의 기본 구현체. 웹에서 네이티브 호출을 위한 JavaScript 코드를 생성한다.
public struct DefaultBridgeSDKProvider: BridgeSDKProvider, Sendable {
    // MARK: - Initializer
    public init() {}

    // MARK: - Public
    public func generateSDK() throws -> String {
        guard let url = Bundle.module.url(forResource: "bridge-sdk", withExtension: "js") else {
            throw BridgeSDKError.sdkResourceNotAvailable(bundlePath: Bundle.module.bundlePath)
        }
        let code = try String(contentsOf: url, encoding: .utf8)
        return code
    }
}
