import Foundation
import Testing
@testable import Core

/// ContainerActor의 등록/해결 기능을 검증한다.
@Suite("ContainerActor")
struct ContainerActorTests {
    // MARK: - Property
    private let container: ContainerActor

    // MARK: - Initializer
    init() {
        container = ContainerActor()
    }

    // MARK: - Public
    @Test("타입을 등록하고 해결할 수 있다")
    func registerAndResolve() async {
        await container.register(String.self) { "hello" }
        let result = await container.resolve(String.self)

        #expect(result == "hello")
    }

    @Test("등록되지 않은 타입을 해결하면 nil을 반환한다")
    func resolveUnregistered() async {
        let result = await container.resolve(Int.self)
        #expect(result == nil)
    }

    @Test("같은 타입을 재등록하면 마지막 팩토리가 사용된다")
    func overwriteRegistration() async {
        await container.register(String.self) { "first" }
        await container.register(String.self) { "second" }
        let result = await container.resolve(String.self)

        #expect(result == "second")
    }

    @Test("여러 타입을 독립적으로 등록하고 해결할 수 있다")
    func multipleTypes() async {
        await container.register(String.self) { "text" }
        await container.register(Int.self) { 42 }

        let text = await container.resolve(String.self)
        let number = await container.resolve(Int.self)

        #expect(text == "text")
        #expect(number == 42)
    }

    @Test("팩토리가 호출될 때마다 새 인스턴스를 생성한다")
    func factoryCreatesNewInstances() async {
        let counter = Counter()
        await container.register(Int.self) {
            counter.increment()
        }

        let first = await container.resolve(Int.self)
        let second = await container.resolve(Int.self)

        #expect(first == 1)
        #expect(second == 2)
    }

    @Test("distinct types with the same description do not collide")
    func distinctTypesDoNotCollide() async {
        await container.register(TypeA.self) { TypeA(value: "A") }
        await container.register(TypeB.self) { TypeB(value: "B") }

        let a = await container.resolve(TypeA.self)
        let b = await container.resolve(TypeB.self)

        #expect(a?.value == "A")
        #expect(b?.value == "B")
    }

    @Test("싱글턴 스코프는 매번 동일한 인스턴스를 반환한다")
    func singletonReturnsSameInstance() async {
        await container.register(Marker.self, scope: .singleton) { Marker() }

        let first = await container.resolve(Marker.self)
        let second = await container.resolve(Marker.self)

        #expect(first != nil)
        #expect(second != nil)
        #expect(first === second)
    }

    @Test("트랜지언트 스코프는 매번 새 인스턴스를 반환한다")
    func transientReturnsNewInstances() async {
        await container.register(Marker.self, scope: .transient) { Marker() }

        let first = await container.resolve(Marker.self)
        let second = await container.resolve(Marker.self)

        #expect(first != nil)
        #expect(second != nil)
        #expect(first !== second)
    }

    @Test("해결 실패 시 로거에 경고 메시지가 기록된다")
    func resolveFailureLogsWarning() async {
        let mockLogger = MockLogger()
        let loggedContainer = ContainerActor(logger: mockLogger)

        let result = await loggedContainer.resolve(Int.self)

        #expect(result == nil)
        #expect(mockLogger.messages.count == 1)
        #expect(mockLogger.messages.first?.level == .warning)
        #expect(mockLogger.messages.first?.message.contains("Int") == true)
    }
}

// MARK: - Test Helper

/// 스레드 안전한 카운터.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private let _value: UnsafeMutablePointer<Int>

    init() {
        _value = .allocate(capacity: 1)
        _value.initialize(to: 0)
    }

    deinit {
        _value.deallocate()
    }

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        _value.pointee += 1
        return _value.pointee
    }
}

private struct TypeA: Sendable {
    let value: String
}

private struct TypeB: Sendable {
    let value: String
}

/// 싱글턴/트랜지언트 스코프 검증을 위한 참조 타입 마커.
private final class Marker: Sendable {}

/// 로그 메시지를 기록하는 모의 로거.
private final class MockLogger: Logger, @unchecked Sendable {
    struct LogEntry {
        let level: LogLevel
        let message: String
    }

    private let lock = NSLock()
    private var _messages: [LogEntry] = []

    var messages: [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return _messages
    }

    func write(_ level: LogLevel, _ message: String, file: String, line: Int) {
        lock.lock()
        defer { lock.unlock() }
        _messages.append(LogEntry(level: level, message: message))
    }
}
