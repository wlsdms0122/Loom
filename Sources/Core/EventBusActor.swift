import Foundation

/// AsyncStream.Continuation의 타입 소거 래퍼.
/// 구체적인 continuation의 `yield`와 `finish`를 클로저로 캡처하여
/// continuation을 `Any`로 저장할 필요를 없앤다.
private struct AnyEventContinuation: Sendable {
    // MARK: - Property
    private let _yield: @Sendable (any Event) -> Void
    private let _finish: @Sendable () -> Void

    // MARK: - Initializer
    init<E: Event>(_ continuation: AsyncStream<E>.Continuation) {
        _yield = { event in
            guard let typed = event as? E else { return }
            continuation.yield(typed)
        }
        _finish = {
            continuation.finish()
        }
    }

    // MARK: - Public
    func yield(_ event: any Event) {
        _yield(event)
    }

    func finish() {
        _finish()
    }
}

/// 이벤트 버스의 Actor 기반 구현체.
public actor EventBusActor: EventBus {
    // MARK: - Property
    private var continuations: [String: [String: AnyEventContinuation]] = [:]

    // MARK: - Initializer
    public init() {}

    // MARK: - Public
    public func emit<E: Event>(_ event: E) {
        let key = E.name
        guard let entries = continuations[key] else { return }
        for (_, entry) in entries {
            entry.yield(event)
        }
    }

    public func on<E: Event>(_ type: E.Type) -> AsyncStream<E> {
        let key = E.name
        let id = UUID().uuidString
        return AsyncStream<E> { continuation in
            if continuations[key] == nil {
                continuations[key] = [:]
            }
            continuations[key]?[id] = AnyEventContinuation(continuation)

            continuation.onTermination = { @Sendable [weak self] _ in
                guard let self else { return }
                Task { await self.removeContinuation(key: key, id: id) }
            }
        }
    }

    /// 현재 등록된 continuation 수를 반환한다. 테스트 용도.
    func continuationCount(for key: String) -> Int {
        continuations[key]?.count ?? 0
    }

    // MARK: - Private
    private func removeContinuation(key: String, id: String) {
        continuations[key]?[id] = nil
        if continuations[key]?.isEmpty == true {
            continuations[key] = nil
        }
    }
}
