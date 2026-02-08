/// 이벤트 프로토콜. 모든 이벤트는 이 프로토콜을 준수해야 한다.
public protocol Event: Sendable {
    /// 이벤트 이름.
    static var name: String { get }
}

/// 이벤트 버스 프로토콜. 이벤트 발행과 구독을 지원한다.
public protocol EventBus: Sendable {
    /// 이벤트를 발행한다.
    func emit<E: Event>(_ event: E) async

    /// 특정 이벤트 타입을 구독하고 AsyncStream을 반환한다.
    func on<E: Event>(_ type: E.Type) async -> AsyncStream<E>
}
