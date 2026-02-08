import Foundation
import Bridge
import Plugin

/// 플러그인의 메서드를 Bridge에 연결하는 유틸리티.
/// 각 플러그인 메서드는 "plugin.{pluginName}.{methodName}" 형식으로 Bridge에 등록된다.
public struct PluginBridgeConnector: Sendable {
    // MARK: - Initializer

    private init() {}

    // MARK: - Public

    /// 플러그인 목록의 모든 메서드를 Bridge에 등록한다.
    public static func connect(
        plugins: [any Plugin],
        to bridge: any Bridge
    ) async {
        for plugin in plugins {
            for method in await plugin.methods() {
                let methodName = "plugin.\(plugin.name).\(method.name)"
                let handler = method.handler
                await bridge.register(method: methodName) { payload in
                    let input = payload ?? "{}"
                    let result = try await handler(input)
                    return result
                }
            }
        }
    }

    /// 플러그인의 메서드를 Bridge에서 등록 해제한다.
    public static func disconnect(
        plugin: any Plugin,
        from bridge: any Bridge
    ) async {
        for method in await plugin.methods() {
            await bridge.unregister(method: "plugin.\(plugin.name).\(method.name)")
        }
    }
}
