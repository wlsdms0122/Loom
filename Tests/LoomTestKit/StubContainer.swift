import Core

/// Shared stub Container for testing. Stores and resolves factories by type name.
public actor StubContainer: Container {
    private var factories: [String: @Sendable () -> any Sendable] = [:]

    public init() {}

    public func register<T: Sendable>(_ type: T.Type, scope: Scope, factory: @escaping @Sendable () -> T) {
        factories[String(describing: type)] = factory
    }

    public func resolve<T: Sendable>(_ type: T.Type) -> T? {
        factories[String(describing: type)]?() as? T
    }
}
