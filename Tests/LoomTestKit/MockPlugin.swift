import Plugin

/// Shared mock Plugin for testing.
public final class MockPlugin: Plugin, @unchecked Sendable {
    // MARK: - Property

    public let name: String
    public private(set) var initializeCalled = false
    public private(set) var disposeCalled = false
    private let _methods: [PluginMethod]
    public var shouldThrowOnInitialize = false
    public var initializeOrder: Int?
    nonisolated(unsafe) private static var _orderCounter = 0

    // MARK: - Initializer

    public init(name: String = "mock", methods: [PluginMethod] = []) {
        self.name = name
        self._methods = methods
    }

    // MARK: - Public

    public static func resetOrderCounter() {
        _orderCounter = 0
    }

    public func initialize(context: any PluginContext) async throws {
        if shouldThrowOnInitialize {
            throw MockPluginError.initializeFailed
        }
        initializeCalled = true
        MockPlugin._orderCounter += 1
        initializeOrder = MockPlugin._orderCounter
    }

    public func methods() async -> [PluginMethod] {
        _methods
    }

    public func dispose() async {
        disposeCalled = true
    }
}

/// Mock plugin error for testing.
public enum MockPluginError: Error {
    case initializeFailed
}
