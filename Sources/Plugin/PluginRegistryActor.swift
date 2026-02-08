import Core

/// 플러그인 레지스트리의 Actor 기반 구현체.
public actor PluginRegistryActor: PluginRegistry {
    // MARK: - Property

    private var orderedKeys: [String] = []
    private var plugins: [String: any Plugin] = [:]
    private let logger: (any Logger)?

    // MARK: - Initializer

    public init(logger: (any Logger)? = nil) {
        self.logger = logger
    }

    // MARK: - Public

    public func register(_ plugin: any Plugin) async {
        let name = plugin.name
        if let existing = plugins[name] {
            logger?.warning("Duplicate plugin registration: '\(name)'. Disposing previous plugin.")
            await existing.dispose()
        } else {
            orderedKeys.append(name)
        }
        plugins[name] = plugin
    }

    public func plugin(named name: String) -> (any Plugin)? {
        plugins[name]
    }

    public func initializeAll(context: any PluginContext) async throws {
        var initialized: [any Plugin] = []
        do {
            for key in orderedKeys {
                guard let plugin = plugins[key] else { continue }
                try await plugin.initialize(context: context)
                initialized.append(plugin)
            }
        } catch {
            for plugin in initialized {
                await plugin.dispose()
            }
            throw error
        }
    }

    public func disposeAll() async {
        for key in orderedKeys {
            guard let plugin = plugins[key] else { continue }
            await plugin.dispose()
        }
        plugins.removeAll()
        orderedKeys.removeAll()
    }

    public func allPlugins() -> [any Plugin] {
        orderedKeys.compactMap { plugins[$0] }
    }
}
