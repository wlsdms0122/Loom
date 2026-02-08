import Foundation

/// JS/Swift 간 통신 브릿지의 핵심 인터페이스.
///
/// 이 프로토콜의 모든 메서드는 `async`로 선언되어 있다.
/// 구현체(`BridgeActor`)가 Swift Actor이므로, Actor 격리(isolation)를 위해 필수적이다.
public protocol Bridge: Sendable {
    /// 메서드 핸들러를 등록한다.
    func register(method: String, handler: @escaping @Sendable (String?) async throws -> String?) async

    /// 등록된 메서드 핸들러를 제거한다.
    func unregister(method: String) async

    /// 웹에서 보낸 단방향 이벤트에 대한 핸들러를 등록한다.
    func onEvent(name: String, handler: @escaping @Sendable (String?) async -> Void) async

    /// 수신된 원시 메시지 문자열을 처리한다.
    func receive(_ rawMessage: String) async

    /// 메시지를 전송한다.
    func send(_ message: BridgeMessage) async throws

    /// 등록된 메서드 핸들러를 모두 제거한다.
    func removeAllHandlers() async

    /// 등록된 이벤트 핸들러를 모두 제거한다.
    func removeAllEventHandlers() async
}
