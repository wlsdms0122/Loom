import Foundation
import Testing
@testable import Core
@testable import Plugin
import LoomTestKit

// MARK: - Test DTO

private struct CountArgs: Codable, Sendable {
    let key: String
}

private struct CountResult: Codable, Sendable {
    let count: Int
}

// MARK: - Actor Plugin

/// 상태를 가진 actor 기반 플러그인. methods() async 변경의 핵심 동기를 검증한다.
private actor CounterPlugin: Plugin {
    nonisolated let name = "counter"
    private var counts: [String: Int] = [:]

    func initialize(context: any PluginContext) async throws {}

    func methods() async -> [PluginMethod] {
        [
            PluginMethod(name: "increment") { [self] (args: CountArgs) async throws -> CountResult in
                let newCount = await self.increment(args.key)
                return CountResult(count: newCount)
            },
            PluginMethod(name: "get") { [self] (args: CountArgs) async throws -> CountResult in
                let count = await self.getCount(args.key)
                return CountResult(count: count)
            },
            PluginMethod(name: "reset") { [self] () async throws in
                await self.resetAll()
            }
        ]
    }

    func dispose() async {
        counts.removeAll()
    }

    // MARK: - Private

    private func increment(_ key: String) -> Int {
        counts[key, default: 0] += 1
        return counts[key]!
    }

    private func getCount(_ key: String) -> Int {
        counts[key, default: 0]
    }

    private func resetAll() {
        counts.removeAll()
    }
}

// MARK: - Stateless Struct Plugin with Actor Store

/// struct Plugin + actor Store 패턴 검증.
private actor CalculatorStore {
    private var history: [String] = []

    func add(_ expression: String, result: Int) {
        history.append("\(expression) = \(result)")
    }

    func getHistory() -> [String] {
        history
    }
}

private struct CalculatorPlugin: Plugin {
    let name = "calculator"
    let store: CalculatorStore

    init(store: CalculatorStore) {
        self.store = store
    }

    func methods() async -> [PluginMethod] {
        [
            PluginMethod(name: "add") { [store] (args: AddArgs) async throws -> AddResult in
                let sum = args.a + args.b
                await store.add("\(args.a)+\(args.b)", result: sum)
                return AddResult(result: sum)
            }
        ]
    }
}

private struct AddArgs: Codable, Sendable {
    let a: Int
    let b: Int
}

private struct AddResult: Codable, Sendable {
    let result: Int
}

// MARK: - Tests

/// Actor 기반 Plugin의 conformance와 thread-safety를 검증한다.
@Suite("Actor Plugin")
struct ActorPluginTests {
    // MARK: - Actor Plugin Conformance

    @Test("actor plugin이 Plugin 프로토콜을 준수한다")
    func actorConformsToPlugin() async {
        let plugin: any Plugin = CounterPlugin()
        #expect(plugin.name == "counter")
    }

    @Test("actor plugin의 methods()가 올바른 메서드를 반환한다")
    func actorMethodsReturned() async {
        let plugin = CounterPlugin()
        let methods = await plugin.methods()
        let names = methods.map(\.name)
        #expect(names == ["increment", "get", "reset"])
    }

    @Test("actor plugin의 메서드를 호출할 수 있다")
    func actorMethodInvocation() async throws {
        let plugin = CounterPlugin()
        let methods = await plugin.methods()
        let increment = try #require(methods.first { $0.name == "increment" })

        let result = try await increment.handler("{\"key\":\"test\"}")
        let decoded = try JSONDecoder().decode(CountResult.self, from: Data(result.utf8))
        #expect(decoded.count == 1)
    }

    @Test("actor plugin에서 상태가 메서드 호출 간에 유지된다")
    func actorStatePersists() async throws {
        let plugin = CounterPlugin()
        let methods = await plugin.methods()
        let increment = try #require(methods.first { $0.name == "increment" })
        let get = try #require(methods.first { $0.name == "get" })

        _ = try await increment.handler("{\"key\":\"a\"}")
        _ = try await increment.handler("{\"key\":\"a\"}")
        _ = try await increment.handler("{\"key\":\"a\"}")

        let result = try await get.handler("{\"key\":\"a\"}")
        let decoded = try JSONDecoder().decode(CountResult.self, from: Data(result.utf8))
        #expect(decoded.count == 3)
    }

    @Test("actor plugin의 동시 호출이 안전하다")
    func actorConcurrentAccessIsSafe() async throws {
        let plugin = CounterPlugin()
        let methods = await plugin.methods()
        let increment = try #require(methods.first { $0.name == "increment" })
        let get = try #require(methods.first { $0.name == "get" })

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    _ = try? await increment.handler("{\"key\":\"concurrent\"}")
                }
            }
        }

        let result = try await get.handler("{\"key\":\"concurrent\"}")
        let decoded = try JSONDecoder().decode(CountResult.self, from: Data(result.utf8))
        #expect(decoded.count == 100)
    }

    @Test("actor plugin의 dispose가 상태를 정리한다")
    func actorDisposeCleanup() async throws {
        let plugin = CounterPlugin()
        let methods = await plugin.methods()
        let increment = try #require(methods.first { $0.name == "increment" })
        let get = try #require(methods.first { $0.name == "get" })

        _ = try await increment.handler("{\"key\":\"x\"}")
        await plugin.dispose()

        let result = try await get.handler("{\"key\":\"x\"}")
        let decoded = try JSONDecoder().decode(CountResult.self, from: Data(result.utf8))
        #expect(decoded.count == 0)
    }

    @Test("actor plugin의 initialize/dispose 라이프사이클이 동작한다")
    func actorLifecycle() async throws {
        let plugin = CounterPlugin()
        let context = MockPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: context)
        await plugin.dispose()
    }

    // MARK: - Struct + Actor Store

    @Test("struct plugin + actor store 패턴이 동작한다")
    func structWithActorStore() async throws {
        let store = CalculatorStore()
        let plugin = CalculatorPlugin(store: store)

        #expect(plugin.name == "calculator")

        let methods = await plugin.methods()
        let add = try #require(methods.first { $0.name == "add" })

        let result = try await add.handler("{\"a\":3,\"b\":4}")
        let decoded = try JSONDecoder().decode(AddResult.self, from: Data(result.utf8))
        #expect(decoded.result == 7)

        let history = await store.getHistory()
        #expect(history == ["3+4 = 7"])
    }

    @Test("struct plugin이 Sendable을 자동으로 만족한다")
    func structPluginSendable() async {
        let store = CalculatorStore()
        let plugin = CalculatorPlugin(store: store)

        let name = await Task {
            plugin.name
        }.value
        #expect(name == "calculator")
    }
}
