import Testing
import Foundation
import Core
import LoomSampleLib
import Plugin

@Suite("GreeterPlugin 테스트")
struct GreeterPluginTests {
    // MARK: - Property

    private let plugin: GreeterPlugin

    // MARK: - Initializer

    init() {
        plugin = GreeterPlugin()
    }

    // MARK: - Property

    @Test("플러그인 이름이 greeter이다")
    func name() {
        #expect(plugin.name == "greeter")
    }

    @Test("메서드가 1개이다")
    func methodCount() async {
        #expect(await plugin.methods().count == 1)
    }

    @Test("hello 메서드가 존재한다")
    func hasHelloMethod() async {
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "hello" }
        #expect(method != nil)
    }

    @Test("메서드 이름이 올바른 순서로 반환된다")
    func methodNames() async {
        let names = await plugin.methods().map(\.name)
        #expect(names == ["hello"])
    }

    // MARK: - Public

    @Test("유효한 이름으로 hello를 호출하면 인사 메시지를 반환한다")
    func helloWithValidName() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "hello" })

        let payload = """
        {"name":"Test"}
        """
        let result = try await method.handler(payload)

        struct Result: Codable { let message: String }
        let decoded = try JSONDecoder().decode(Result.self, from: Data(result.utf8))
        #expect(decoded.message == "Hello, Test! Welcome to Loom.")
    }

    @Test("응답이 유효한 JSON이다")
    func responseIsValidJSON() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "hello" })

        let payload = """
        {"name":"JSON"}
        """
        let result = try await method.handler(payload)

        struct Result: Codable { let message: String }
        let decoded = try JSONDecoder().decode(Result.self, from: Data(result.utf8))
        #expect(decoded.message.isEmpty == false)
    }

    @Test("이름에 특수문자와 유니코드가 포함되어도 정상 동작한다")
    func helloWithSpecialCharactersAndUnicode() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "hello" })

        let payload = """
        {"name":"안녕 🌍"}
        """
        let result = try await method.handler(payload)

        struct Result: Codable { let message: String }
        let decoded = try JSONDecoder().decode(Result.self, from: Data(result.utf8))
        #expect(decoded.message == "Hello, 안녕 🌍! Welcome to Loom.")
    }

    @Test("name 필드가 없는 JSON을 전달하면 에러가 발생한다")
    func helloWithMissingNameField() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "hello" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("{}")
        }
    }

    @Test("잘못된 JSON 문자열을 전달하면 에러가 발생한다")
    func helloWithInvalidJSON() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "hello" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("invalid json")
        }
    }

    @Test("빈 문자열 이름을 전달하면 정상 동작한다")
    func helloWithEmptyName() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "hello" })

        let payload = """
        {"name":""}
        """
        let result = try await method.handler(payload)

        struct Result: Codable { let message: String }
        let decoded = try JSONDecoder().decode(Result.self, from: Data(result.utf8))
        #expect(decoded.message == "Hello, ! Welcome to Loom.")
    }

    @Test("initialize가 에러 없이 완료된다")
    func initializeSucceeds() async throws {
        // GreeterPlugin.initialize는 no-op이므로 임의의 context 없이도
        // 에러가 발생하지 않는지만 확인한다.
        // Plugin 프로토콜 요구사항에 따라 PluginContext가 필요하므로
        // 빈 구현의 context를 전달한다.
        try await plugin.initialize(context: StubPluginContext())
    }

    @Test("dispose가 에러 없이 완료된다")
    func disposeSucceeds() async {
        await plugin.dispose()
    }

    @Test("다양한 이름으로 연속 호출하면 각각 독립적인 결과를 반환한다")
    func helloMultipleTimes() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "hello" })

        struct Result: Codable { let message: String }

        let names = ["Alice", "Bob", "Charlie"]
        for name in names {
            let payload = """
            {"name":"\(name)"}
            """
            let result = try await method.handler(payload)
            let decoded = try JSONDecoder().decode(Result.self, from: Data(result.utf8))
            #expect(decoded.message == "Hello, \(name)! Welcome to Loom.")
        }
    }
}

// MARK: - Stub

/// initialize 테스트를 위한 최소 PluginContext 구현.
private struct StubPluginContext: PluginContext, Sendable {
    let container: any ContainerResolver
    let eventBus: any EventBus
    let logger: any Logger

    init() {
        container = StubContainer()
        eventBus = StubEventBus()
        logger = StubLogger()
    }

    func emit(event: String, data: String) async throws {}
}

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
