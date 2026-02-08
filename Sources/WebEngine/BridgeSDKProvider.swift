/// Bridge JS SDK 코드 제공자 프로토콜.
public protocol BridgeSDKProvider: Sendable {
    /// Bridge SDK JavaScript 코드 문자열을 반환한다.
    /// - Throws: 번들 리소스를 찾을 수 없거나 읽을 수 없을 때.
    func generateSDK() throws -> String
}
