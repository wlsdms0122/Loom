import Testing
import Core
@testable import Plugin
import LoomTestKit

@Suite("PluginRegistryActor 테스트")
struct PluginRegistryActorTests {
    // MARK: - Property

    private let registry: PluginRegistryActor

    // MARK: - Initializer

    init() {
        registry = PluginRegistryActor()
    }

    // MARK: - Tests

    @Test("플러그인을 등록하고 이름으로 조회할 수 있다")
    func registerAndRetrieve() async {
        let plugin = MockPlugin(name: "test")

        await registry.register(plugin)
        let found = await registry.plugin(named: "test")

        #expect(found != nil)
        #expect(found?.name == "test")
    }

    @Test("존재하지 않는 이름으로 조회하면 nil을 반환한다")
    func pluginNotFound() async {
        let result = await registry.plugin(named: "nonexistent")
        #expect(result == nil)
    }

    @Test("여러 플러그인을 등록하고 allPlugins로 조회할 수 있다")
    func registerMultiplePlugins() async {
        let plugin1 = MockPlugin(name: "alpha")
        let plugin2 = MockPlugin(name: "beta")

        await registry.register(plugin1)
        await registry.register(plugin2)

        let all = await registry.allPlugins()
        let names = Set(all.map(\.name))

        #expect(all.count == 2)
        #expect(names.contains("alpha"))
        #expect(names.contains("beta"))
    }

    @Test("같은 이름으로 등록하면 기존 플러그인이 교체된다")
    func registerOverwrite() async {
        let plugin1 = MockPlugin(name: "dup")
        let plugin2 = MockPlugin(name: "dup")

        await registry.register(plugin1)
        await registry.register(plugin2)

        let all = await registry.allPlugins()
        #expect(all.count == 1)
    }

    @Test("initializeAll이 모든 플러그인의 initialize를 호출한다")
    func initializeAll() async throws {
        let plugin1 = MockPlugin(name: "a")
        let plugin2 = MockPlugin(name: "b")
        let context = MockPluginContext(
            container: ContainerActor(),
            eventBus: EventBusActor(),
            logger: StubLogger()
        )

        await registry.register(plugin1)
        await registry.register(plugin2)
        try await registry.initializeAll(context: context)

        #expect(plugin1.initializeCalled)
        #expect(plugin2.initializeCalled)
    }

    @Test("disposeAll이 모든 플러그인을 해제하고 레지스트리를 비운다")
    func disposeAll() async {
        let plugin1 = MockPlugin(name: "a")
        let plugin2 = MockPlugin(name: "b")

        await registry.register(plugin1)
        await registry.register(plugin2)
        await registry.disposeAll()

        #expect(plugin1.disposeCalled)
        #expect(plugin2.disposeCalled)

        let all = await registry.allPlugins()
        #expect(all.isEmpty)
    }

    @Test("initializeAll 중 실패 시 이미 초기화된 플러그인의 dispose가 호출된다")
    func initializeAllRollbackOnFailure() async {
        let plugin1 = MockPlugin(name: "first")
        let plugin2 = MockPlugin(name: "second")
        plugin2.shouldThrowOnInitialize = true
        let plugin3 = MockPlugin(name: "third")

        let context = MockPluginContext(
            container: ContainerActor(),
            eventBus: EventBusActor(),
            logger: StubLogger()
        )

        await registry.register(plugin1)
        await registry.register(plugin2)
        await registry.register(plugin3)

        await #expect(throws: MockPluginError.self) {
            try await registry.initializeAll(context: context)
        }

        #expect(plugin1.initializeCalled)
        #expect(plugin1.disposeCalled)
        #expect(!plugin2.initializeCalled)
        #expect(!plugin3.initializeCalled)
    }

    @Test("중복 이름 등록 시 기존 플러그인의 dispose가 호출되고 새 플러그인으로 교체된다")
    func duplicateRegistrationDisposesOldPlugin() async {
        let pluginA = MockPlugin(name: "test")
        let pluginB = MockPlugin(name: "test")

        await registry.register(pluginA)
        await registry.register(pluginB)

        #expect(pluginA.disposeCalled)

        let found = await registry.plugin(named: "test")
        #expect(found?.name == "test")

        let all = await registry.allPlugins()
        #expect(all.count == 1)
    }

    @Test("기본 구현만으로도 플러그인을 등록하고 초기화할 수 있다")
    func defaultImplementationPlugin() async throws {
        let plugin = MinimalPlugin()
        let context = MockPluginContext(
            container: ContainerActor(),
            eventBus: EventBusActor(),
            logger: StubLogger()
        )

        await registry.register(plugin)
        try await registry.initializeAll(context: context)

        let found = await registry.plugin(named: "minimal")
        #expect(found != nil)
        #expect(found?.name == "minimal")

        await registry.disposeAll()
        let all = await registry.allPlugins()
        #expect(all.isEmpty)
    }

    @Test("플러그인 초기화 순서가 등록 순서와 동일하다")
    func deterministicInitializationOrder() async throws {
        MockPlugin.resetOrderCounter()

        let pluginA = MockPlugin(name: "alpha")
        let pluginB = MockPlugin(name: "beta")
        let pluginC = MockPlugin(name: "gamma")

        let context = MockPluginContext(
            container: ContainerActor(),
            eventBus: EventBusActor(),
            logger: StubLogger()
        )

        await registry.register(pluginA)
        await registry.register(pluginB)
        await registry.register(pluginC)

        try await registry.initializeAll(context: context)

        #expect(pluginA.initializeOrder == 1)
        #expect(pluginB.initializeOrder == 2)
        #expect(pluginC.initializeOrder == 3)
    }
}

// MARK: - MinimalPlugin

/// 기본 구현(initialize/dispose)만 사용하는 최소 플러그인.
private struct MinimalPlugin: Plugin {
    let name = "minimal"

    func methods() async -> [PluginMethod] {
        [
            PluginMethod(name: "ping") { _ in
                return "{\"pong\":true}"
            }
        ]
    }
}
