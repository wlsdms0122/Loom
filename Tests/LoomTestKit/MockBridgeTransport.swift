import Foundation
import Bridge

/// Shared mock BridgeTransport for testing. Records all sent data.
public final class MockBridgeTransport: BridgeTransport, @unchecked Sendable {
    // MARK: - Property

    private let _lock = NSLock()
    private var _sentData: [Data] = []

    public var sentData: [Data] { _lock.withLock { _sentData } }

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func send(_ data: Data) async throws {
        _lock.withLock { _sentData.append(data) }
    }
}
