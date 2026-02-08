import Foundation
import Core
import Bridge
import Plugin

/// LoomApp에서 사용하는 PluginContext 구현체.
struct LoomPluginContext: PluginContext, Sendable {
    // MARK: - Property
    let container: any ContainerResolver
    let eventBus: any EventBus
    let logger: any Logger
    private let bridge: any Bridge

    // MARK: - Initializer
    init(
        container: any ContainerResolver,
        eventBus: any EventBus,
        logger: any Logger,
        bridge: any Bridge
    ) {
        self.container = container
        self.eventBus = eventBus
        self.logger = logger
        self.bridge = bridge
    }

    // MARK: - Public
    func emit(event: String, data: String) async throws {
        let message = BridgeMessage(
            id: UUID().uuidString,
            method: event,
            payload: data,
            kind: .nativeEvent
        )
        try await bridge.send(message)
    }
}
