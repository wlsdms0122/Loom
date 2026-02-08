import Core

/// Shared stub EventBus for testing. Emits nothing and returns finished streams.
public actor StubEventBus: EventBus {
    public init() {}

    public func emit<E: Event>(_ event: E) async {}

    public func on<E: Event>(_ type: E.Type) async -> AsyncStream<E> {
        AsyncStream { $0.finish() }
    }
}
