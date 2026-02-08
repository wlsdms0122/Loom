import Testing
import Foundation
import Core
@testable import Plugin
import Platform
import LoomTestKit

@Suite("WindowPlugin 테스트")
struct WindowPluginTests {
    // MARK: - Property

    private let windowHandle: WindowHandle

    // MARK: - Initializer

    init() {
        windowHandle = WindowHandle(id: "test-window", title: "Test")
    }

    // MARK: - Tests

    @Test("플러그인 이름이 window이다")
    func name() {
        let plugin = WindowPlugin(windowHandle: windowHandle)
        #expect(plugin.name == "window")
    }

    @Test("메서드가 1개이다")
    func methodCount() async {
        let plugin = WindowPlugin(windowHandle: windowHandle)
        #expect(await plugin.methods().count == 1)
    }

    @Test("startDrag 메서드가 존재한다")
    func hasStartDragMethod() async {
        let plugin = WindowPlugin(windowHandle: windowHandle)
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "startDrag" }
        #expect(method != nil)
    }

    @Test("initialize가 에러 없이 완료된다")
    func initializeSucceeds() async throws {
        let plugin = WindowPlugin(windowHandle: windowHandle)
        let context = MockPluginContext(
            container: ContainerActor(),
            eventBus: EventBusActor(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: context)
    }

    @Test("dispose가 에러 없이 완료된다")
    func disposeSucceeds() async {
        let plugin = WindowPlugin(windowHandle: windowHandle)
        await plugin.dispose()
    }

    @Test("WindowManager가 없으면 startDrag 호출 시 unsupportedPlatform 에러가 발생한다")
    func startDragWithoutWindowManagerThrows() async throws {
        let plugin = WindowPlugin(windowHandle: windowHandle)
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "startDrag" })

        await #expect(throws: PluginError.self) {
            _ = try await method.handler("{}")
        }
    }

    @Test("startDrag 호출 시 WindowManager.performDrag가 호출된다")
    func startDragCallsPerformDrag() async throws {
        let mockWM = MockWindowManager()
        let (plugin, _) = try await Self.makeInitializedPlugin(
            windowHandle: windowHandle,
            windowManager: mockWM
        )

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "startDrag" })

        let result = try await method.handler("{}")
        #expect(result == "{}")
        #expect(mockWM.draggedHandles.count == 1)
        #expect(mockWM.draggedHandles.first == windowHandle)
    }

    // MARK: - Helper

    private static func makeInitializedPlugin(
        windowHandle: WindowHandle,
        windowManager: MockWindowManager
    ) async throws -> (WindowPlugin, StubContainer) {
        let container = StubContainer()
        let wmRef: any WindowManager = windowManager
        await container.register((any WindowManager).self, scope: .singleton) { wmRef }
        let context = MockPluginContext(
            container: container,
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        let plugin = WindowPlugin(windowHandle: windowHandle)
        try await plugin.initialize(context: context)
        return (plugin, container)
    }
}
