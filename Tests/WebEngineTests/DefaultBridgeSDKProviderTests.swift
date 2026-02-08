import Testing
@testable import WebEngine

/// DefaultBridgeSDKProvider의 SDK 생성을 검증한다.
@Suite("DefaultBridgeSDKProvider")
struct DefaultBridgeSDKProviderTests {
    // MARK: - Property
    private let provider: DefaultBridgeSDKProvider

    // MARK: - Initializer
    init() {
        provider = DefaultBridgeSDKProvider()
    }

    // MARK: - Public
    @Test("SDK 코드가 비어 있지 않다")
    func sdkIsNotEmpty() throws {
        let sdk = try provider.generateSDK()
        #expect(!sdk.isEmpty)
    }

    @Test("BridgeSDKProvider 프로토콜을 준수한다")
    func conformsToBridgeSDKProvider() {
        let _: any BridgeSDKProvider = provider
    }
}
