import Foundation
import Bridge

/// Shared mock Bridge for testing. Records registered handlers.
public actor MockBridge: Bridge {
    // MARK: - Property

    private var handlers: [String: @Sendable (String?) async throws -> String?] = [:]
    private var eventHandlers: [String: [@Sendable (String?) async -> Void]] = [:]

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func register(method: String, handler: @escaping @Sendable (String?) async throws -> String?) {
        handlers[method] = handler
    }

    public func unregister(method: String) {
        handlers.removeValue(forKey: method)
    }

    public func onEvent(name: String, handler: @escaping @Sendable (String?) async -> Void) {
        eventHandlers[name, default: []].append(handler)
    }

    public func receive(_ rawMessage: String) async {}

    public func send(_ message: BridgeMessage) async throws {}

    public func removeAllHandlers() {
        handlers.removeAll()
    }

    public func removeAllEventHandlers() {
        eventHandlers.removeAll()
    }

    /// Returns sorted list of registered handler names.
    public func registeredNames() -> [String] {
        Array(handlers.keys).sorted()
    }

    /// Looks up a handler by name.
    public func handler(named name: String) -> (@Sendable (String?) async throws -> String?)? {
        handlers[name]
    }
}
