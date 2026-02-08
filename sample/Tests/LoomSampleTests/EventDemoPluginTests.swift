import Testing
import Foundation
import Core
import LoomSampleLib
import Plugin

// MARK: - SpyPluginContext

/// emit 호출을 기록하는 모의 PluginContext.
private final class SpyPluginContext: PluginContext, @unchecked Sendable {
    let container: any ContainerResolver
    let eventBus: any EventBus
    let logger: any Logger

    private let _lock = NSLock()
    private var _emittedEvents: [(event: String, data: String)] = []

    var emittedEvents: [(event: String, data: String)] {
        _lock.withLock { _emittedEvents }
    }

    init(container: any ContainerResolver, eventBus: any EventBus, logger: any Logger) {
        self.container = container
        self.eventBus = eventBus
        self.logger = logger
    }

    func emit(event: String, data: String) async throws {
        _lock.withLock { _emittedEvents.append((event: event, data: data)) }
    }
}

// MARK: - Stubs

private struct StubContainer: Container, Sendable {
    func register<T: Sendable>(_ type: T.Type, scope: Scope, factory: @escaping @Sendable () -> T) async {}
    func resolve<T: Sendable>(_ type: T.Type) async -> T? { nil }
}

private struct StubEventBus: EventBus, Sendable {
    func emit<E: Event>(_ event: E) async {}
    func on<E: Event>(_ type: E.Type) async -> AsyncStream<E> {
        AsyncStream { $0.finish() }
    }
}

private struct StubLogger: Logger, Sendable {
    func write(_ level: LogLevel, _ message: String, file: String, line: Int) {}
}

// MARK: - Tests

@Suite("EventDemoPlugin 테스트")
struct EventDemoPluginTests {
    // MARK: - Property

    private let plugin: EventDemoPlugin

    // MARK: - Initializer

    init() {
        plugin = EventDemoPlugin()
    }

    // MARK: - Property

    @Test("플러그인 이름이 eventDemo이다")
    func name() {
        #expect(plugin.name == "eventDemo")
    }

    @Test("메서드가 1개이다")
    func methodCount() async {
        #expect(await plugin.methods().count == 1)
    }

    @Test("emit 메서드가 존재한다")
    func hasEmitMethod() async {
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "emit" }
        #expect(method != nil)
    }

    @Test("메서드 이름이 올바른 순서로 반환된다")
    func methodNames() async {
        let names = await plugin.methods().map(\.name)
        #expect(names == ["emit"])
    }

    // MARK: - Public

    @Test("initialize 전에 emit을 호출하면 notInitialized 에러가 발생한다")
    func emitBeforeInitializeThrowsNotInitialized() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "emit" })

        let payload = """
        {"event":"test.event"}
        """
        await #expect(throws: PluginError.self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("initialize 후 emit이 context.emit을 올바르게 호출한다")
    func emitAfterInitializeCallsContextEmit() async throws {
        let spy = SpyPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: spy)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "emit" })

        let payload = """
        {"event":"user.click","data":"{\\"button\\":\\"submit\\"}"}
        """
        let result = try await method.handler(payload)
        #expect(result == "{}")

        let events = spy.emittedEvents
        #expect(events.count == 1)
        #expect(events.first?.event == "user.click")
        #expect(events.first?.data == "{\"button\":\"submit\"}")
    }

    @Test("data가 nil이면 기본 timestamp JSON이 전달된다")
    func emitWithNilDataUsesDefaultTimestamp() async throws {
        let spy = SpyPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: spy)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "emit" })

        let payload = """
        {"event":"heartbeat"}
        """
        let result = try await method.handler(payload)
        #expect(result == "{}")

        let events = spy.emittedEvents
        #expect(events.count == 1)
        #expect(events.first?.event == "heartbeat")

        let data = try #require(events.first?.data)
        #expect(data.contains("\"timestamp\":"))
    }

    @Test("emit에 잘못된 JSON을 전달하면 에러가 발생한다")
    func emitInvalidPayload() async throws {
        let spy = SpyPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: spy)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "emit" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("invalid json")
        }
    }

    @Test("emit에 event 필드가 없으면 에러가 발생한다")
    func emitMissingEventField() async throws {
        let spy = SpyPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: spy)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "emit" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("{\"data\":\"hello\"}")
        }
    }

    @Test("dispose 후 emit을 호출하면 notInitialized 에러가 발생한다")
    func emitAfterDisposeThrowsNotInitialized() async throws {
        let spy = SpyPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: spy)
        await plugin.dispose()

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "emit" })

        let payload = """
        {"event":"post.dispose"}
        """
        await #expect(throws: PluginError.self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("emit은 빈 JSON을 반환한다")
    func emitReturnsEmptyJSON() async throws {
        let spy = SpyPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: spy)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "emit" })

        let payload = """
        {"event":"test"}
        """
        let result = try await method.handler(payload)
        #expect(result == "{}")
    }

    @Test("initialize가 에러 없이 완료된다")
    func initializeSucceeds() async throws {
        let spy = SpyPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: spy)
    }

    @Test("dispose가 에러 없이 완료된다")
    func disposeSucceeds() async {
        await plugin.dispose()
    }

    @Test("emit을 여러 번 호출하면 각각 독립적으로 이벤트가 전송된다")
    func emitMultipleTimes() async throws {
        let spy = SpyPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: spy)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "emit" })

        let payload1 = """
        {"event":"event.a","data":"{\\"n\\":1}"}
        """
        let payload2 = """
        {"event":"event.b","data":"{\\"n\\":2}"}
        """
        _ = try await method.handler(payload1)
        _ = try await method.handler(payload2)

        let events = spy.emittedEvents
        #expect(events.count == 2)
        #expect(events[0].event == "event.a")
        #expect(events[0].data == "{\"n\":1}")
        #expect(events[1].event == "event.b")
        #expect(events[1].data == "{\"n\":2}")
    }
}
