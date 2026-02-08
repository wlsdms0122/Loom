import Foundation

/// 메시지의 실제 전송 채널 추상화. WebEngine이 구현한다.
public protocol BridgeTransport: Sendable {
    /// 인코딩된 메시지 데이터를 웹 엔진에 전달한다.
    func send(_ data: Data) async throws
}
