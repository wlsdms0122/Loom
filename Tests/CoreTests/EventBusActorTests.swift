import Testing
@testable import Core

/// EventBusActor의 이벤트 발행/구독을 검증한다.
@Suite("EventBusActor")
struct EventBusActorTests {
    // MARK: - Property
    private let eventBus: EventBusActor

    // MARK: - Initializer
    init() {
        eventBus = EventBusActor()
    }

    // MARK: - Public
    @Test("이벤트를 발행하고 구독자가 수신할 수 있다")
    func emitAndReceive() async {
        let stream = await eventBus.on(TestEvent.self)
        await eventBus.emit(TestEvent(value: "hello"))

        var received: String?
        for await event in stream {
            received = event.value
            break
        }

        #expect(received == "hello")
    }

    @Test("구독 전에 발행된 이벤트는 수신되지 않는다")
    func missedEvents() async {
        await eventBus.emit(TestEvent(value: "missed"))
        let stream = await eventBus.on(TestEvent.self)

        // 새 이벤트를 발행하여 스트림이 첫 번째 이벤트만 반환하는지 확인한다.
        await eventBus.emit(TestEvent(value: "received"))

        var received: String?
        for await event in stream {
            received = event.value
            break
        }

        #expect(received == "received")
    }

    @Test("구독 종료 시 continuation이 정리된다")
    func cleanupOnTermination() async throws {
        // 스트림을 생성하면 continuation이 등록된다.
        let stream = await eventBus.on(TestEvent.self)
        let countBefore = await eventBus.continuationCount(for: TestEvent.name)
        #expect(countBefore == 1)

        // Task를 통해 스트림을 소비하고, Task 취소로 스트림을 종료한다.
        let task = Task {
            for await _ in stream {}
        }
        // 이벤트를 발행하여 스트림이 활성 상태인지 확인한다.
        await eventBus.emit(TestEvent(value: "done"))

        // Task를 취소하면 onTermination이 호출된다.
        task.cancel()

        // onTermination 내부의 Task가 actor 메서드를 호출하므로,
        // continuation이 정리될 때까지 양보(yield)하며 폴링한다.
        for _ in 0..<200 {
            if await eventBus.continuationCount(for: TestEvent.name) == 0 { break }
            await Task.yield()
        }

        let countAfter = await eventBus.continuationCount(for: TestEvent.name)
        #expect(countAfter == 0)
    }

    @Test("여러 구독자가 독립적으로 정리된다")
    func multipleSubscribersCleanup() async throws {
        // 두 개의 스트림을 생성한다.
        let stream1 = await eventBus.on(TestEvent.self)
        let stream2 = await eventBus.on(TestEvent.self)
        let countInitial = await eventBus.continuationCount(for: TestEvent.name)
        #expect(countInitial == 2)

        // 각 스트림을 별도 Task에서 소비한다.
        let task1 = Task {
            for await _ in stream1 {}
        }
        let task2 = Task {
            for await _ in stream2 {}
        }

        // 이벤트를 발행하여 스트림이 활성 상태인지 확인한다.
        await eventBus.emit(TestEvent(value: "event"))

        // task1만 취소한다.
        task1.cancel()

        // onTermination 내부의 Task가 actor 메서드를 호출하므로,
        // continuation이 정리될 때까지 양보(yield)하며 폴링한다.
        for _ in 0..<200 {
            if await eventBus.continuationCount(for: TestEvent.name) == 1 { break }
            await Task.yield()
        }

        // stream1만 정리되고 stream2는 남아있어야 한다.
        let countAfterFirst = await eventBus.continuationCount(for: TestEvent.name)
        #expect(countAfterFirst == 1)

        // task2도 취소한다.
        task2.cancel()

        for _ in 0..<200 {
            if await eventBus.continuationCount(for: TestEvent.name) == 0 { break }
            await Task.yield()
        }

        // 모든 continuation이 정리되어야 한다.
        let countAfterSecond = await eventBus.continuationCount(for: TestEvent.name)
        #expect(countAfterSecond == 0)
    }
    @Test("different event types with the same name are isolated")
    func differentEventTypesAreIsolated() async {
        let streamA = await eventBus.on(TestEvent.self)
        let streamB = await eventBus.on(OtherEvent.self)

        await eventBus.emit(TestEvent(value: "for-A"))
        await eventBus.emit(OtherEvent(code: 42))

        var receivedA: String?
        for await event in streamA {
            receivedA = event.value
            break
        }

        var receivedB: Int?
        for await event in streamB {
            receivedB = event.code
            break
        }

        #expect(receivedA == "for-A")
        #expect(receivedB == 42)
    }
}

// MARK: - Test Helper

/// 테스트용 이벤트.
struct TestEvent: Event {
    static let name = "test.event"
    let value: String
}

/// Type isolation test event.
struct OtherEvent: Event {
    static let name = "other.event"
    let code: Int
}
