import Core
import Plugin

/// Shared mock PluginContext for testing.
public struct MockPluginContext: PluginContext, Sendable {
    public let container: any ContainerResolver
    public let eventBus: any EventBus
    public let logger: any Logger

    public init(container: any ContainerResolver, eventBus: any EventBus, logger: any Logger) {
        self.container = container
        self.eventBus = eventBus
        self.logger = logger
    }

    public func emit(event: String, data: String) async throws {}
}
