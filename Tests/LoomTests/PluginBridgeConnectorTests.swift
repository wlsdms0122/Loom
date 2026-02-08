import Testing
import Foundation
import Bridge
import Plugin
@testable import Loom
import LoomTestKit

@Suite("PluginBridgeConnector 테스트")
struct PluginBridgeConnectorTests {
    // MARK: - Tests

    @Test("플러그인 메서드가 올바른 경로로 Bridge에 등록된다")
    func connectRegistersCorrectPaths() async {
        let methods = [
            PluginMethod(name: "read") { _ in "{}" },
            PluginMethod(name: "write") { _ in "{}" }
        ]
        let plugin = MockPlugin(name: "filesystem", methods: methods)
        let bridge = MockBridge()

        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)

        let names = await bridge.registeredNames()
        #expect(names.contains("plugin.filesystem.read"))
        #expect(names.contains("plugin.filesystem.write"))
    }

    @Test("여러 플러그인의 메서드가 모두 등록된다")
    func connectMultiplePlugins() async {
        let fsPlugin = MockPlugin(name: "filesystem", methods: [
            PluginMethod(name: "list") { _ in "{}" }
        ])
        let clipPlugin = MockPlugin(name: "clipboard", methods: [
            PluginMethod(name: "readText") { _ in "{}" }
        ])
        let bridge = MockBridge()

        await PluginBridgeConnector.connect(plugins: [fsPlugin, clipPlugin], to: bridge)

        let names = await bridge.registeredNames()
        #expect(names.contains("plugin.filesystem.list"))
        #expect(names.contains("plugin.clipboard.readText"))
        #expect(names.count == 2)
    }

    @Test("메서드가 없는 플러그인은 핸들러를 등록하지 않는다")
    func connectEmptyPlugin() async {
        let plugin = MockPlugin(name: "empty", methods: [])
        let bridge = MockBridge()

        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)

        let names = await bridge.registeredNames()
        #expect(names.isEmpty)
    }

    // MARK: - disconnect 테스트

    @Test("disconnect가 플러그인의 모든 메서드를 Bridge에서 해제한다")
    func disconnectRemovesAllMethods() async {
        let methods = [
            PluginMethod(name: "read") { _ in "{}" },
            PluginMethod(name: "write") { _ in "{}" }
        ]
        let plugin = MockPlugin(name: "filesystem", methods: methods)
        let bridge = MockBridge()

        // 먼저 등록한다.
        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)

        let namesBefore = await bridge.registeredNames()
        #expect(namesBefore.contains("plugin.filesystem.read"))
        #expect(namesBefore.contains("plugin.filesystem.write"))

        // disconnect로 해제한다.
        await PluginBridgeConnector.disconnect(plugin: plugin, from: bridge)

        let namesAfter = await bridge.registeredNames()
        #expect(!namesAfter.contains("plugin.filesystem.read"))
        #expect(!namesAfter.contains("plugin.filesystem.write"))
    }

    @Test("disconnect 후 Bridge에서 해당 플러그인의 핸들러를 찾을 수 없다")
    func disconnectHandlerNotFound() async {
        let methods = [
            PluginMethod(name: "echo") { payload in payload }
        ]
        let plugin = MockPlugin(name: "test", methods: methods)
        let bridge = MockBridge()

        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)

        // 핸들러가 존재하는지 확인한다.
        let handlerBefore = await bridge.handler(named: "plugin.test.echo")
        #expect(handlerBefore != nil)

        // disconnect 후 핸들러가 nil인지 확인한다.
        await PluginBridgeConnector.disconnect(plugin: plugin, from: bridge)

        let handlerAfter = await bridge.handler(named: "plugin.test.echo")
        #expect(handlerAfter == nil)
    }

    @Test("disconnect는 다른 플러그인의 메서드에 영향을 주지 않는다")
    func disconnectDoesNotAffectOtherPlugins() async {
        let fsPlugin = MockPlugin(name: "filesystem", methods: [
            PluginMethod(name: "read") { _ in "{}" }
        ])
        let clipPlugin = MockPlugin(name: "clipboard", methods: [
            PluginMethod(name: "readText") { _ in "{}" }
        ])
        let bridge = MockBridge()

        await PluginBridgeConnector.connect(plugins: [fsPlugin, clipPlugin], to: bridge)

        // filesystem 플러그인만 해제한다.
        await PluginBridgeConnector.disconnect(plugin: fsPlugin, from: bridge)

        let names = await bridge.registeredNames()
        #expect(!names.contains("plugin.filesystem.read"))
        #expect(names.contains("plugin.clipboard.readText"))
    }

    @Test("메서드가 없는 플러그인의 disconnect는 에러 없이 완료된다")
    func disconnectEmptyPlugin() async {
        let plugin = MockPlugin(name: "empty", methods: [])
        let bridge = MockBridge()

        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)
        await PluginBridgeConnector.disconnect(plugin: plugin, from: bridge)

        let names = await bridge.registeredNames()
        #expect(names.isEmpty)
    }

    // MARK: - 핸들러 실행 테스트

    @Test("nil 페이로드를 전달하면 플러그인 핸들러가 빈 JSON을 수신한다")
    func nilPayloadDefaultsToEmptyJSON() async throws {
        let captured = PayloadCapture()
        let methods = [
            PluginMethod(name: "check") { payload in
                captured.value = payload
                return "{}"
            }
        ]
        let plugin = MockPlugin(name: "test", methods: methods)
        let bridge = MockBridge()

        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)

        let bridgeHandler = try #require(await bridge.handler(named: "plugin.test.check"))
        _ = try await bridgeHandler(nil)

        #expect(captured.value == "{}")
    }

    @Test("등록된 핸들러가 올바르게 메시지를 처리한다")
    func handlerProcessesMessage() async throws {
        let methods = [
            PluginMethod(name: "echo") { payload in
                payload
            }
        ]
        let plugin = MockPlugin(name: "test", methods: methods)
        let bridge = MockBridge()

        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)

        let handler = await bridge.handler(named: "plugin.test.echo")
        let bridgeHandler = try #require(handler)

        let inputPayload = "{\"msg\":\"hello\"}"
        let result = try await bridgeHandler(inputPayload)
        let resultString = try #require(result)
        #expect(resultString == "{\"msg\":\"hello\"}")
    }
}

// MARK: - Helper

/// 핸들러에서 전달받은 페이로드를 캡처하기 위한 유틸리티.
private final class PayloadCapture: @unchecked Sendable {
    var value: String?
}
