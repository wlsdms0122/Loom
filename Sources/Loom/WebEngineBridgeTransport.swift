import Foundation
import Bridge
import WebEngine

/// WebEngine을 BridgeTransport로 연결하는 경량 어댑터.
/// 인코딩된 메시지 Data를 Base64로 변환하고 JS SDK의 receive 함수를 호출한다.
struct WebEngineBridgeTransport: BridgeTransport {
    let engine: any WebEngine

    func send(_ data: Data) async throws {
        let base64 = data.base64EncodedString()
        let script = "window.__loom__.receive('\(base64)')"
        _ = try await engine.evaluateJavaScript(script)
    }
}
