import Foundation

/// JS/Swift 간 교환되는 메시지 포맷.
public struct BridgeMessage: Sendable, Codable {
    // MARK: - Property

    /// 메시지 고유 식별자.
    public let id: String

    /// 호출할 메서드 이름.
    public let method: String

    /// 메시지 페이로드. JSON 문자열.
    public let payload: String?

    /// 메시지 종류.
    public let kind: MessageKind

    /// 메시지 종류를 나타내는 열거형.
    public enum MessageKind: String, Sendable, Codable {
        case request
        case response
        /// Native -> Web one-way event. Dispatched to JS listeners via `loom.on()`.
        case nativeEvent
        case error
        /// Web -> Native one-way event. No response expected. Sent from JS via `loom.emit()`.
        case webEvent
    }

    // MARK: - Initializer

    public init(id: String, method: String, payload: String?, kind: MessageKind) {
        self.id = id
        self.method = method
        self.payload = payload
        self.kind = kind
    }
}
