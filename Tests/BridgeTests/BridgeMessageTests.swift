import Foundation
import Testing
@testable import Bridge

/// BridgeMessage의 Codable 직렬화/역직렬화를 검증한다.
@Suite("BridgeMessage")
struct BridgeMessageTests {
    // MARK: - Property

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Public

    @Test("페이로드가 있는 메시지를 인코딩/디코딩할 수 있다")
    func encodeDecode() throws {
        let payload = "{\"key\":\"value\"}"
        let message = BridgeMessage(
            id: "msg_1",
            method: "test.method",
            payload: payload,
            kind: .request
        )

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(BridgeMessage.self, from: data)

        #expect(decoded.id == "msg_1")
        #expect(decoded.method == "test.method")
        #expect(decoded.payload == payload)
        #expect(decoded.kind == .request)
    }

    @Test("페이로드가 nil인 메시지를 인코딩/디코딩할 수 있다")
    func encodeDecodeNilPayload() throws {
        let message = BridgeMessage(
            id: "msg_2",
            method: "test.empty",
            payload: nil,
            kind: .response
        )

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(BridgeMessage.self, from: data)

        #expect(decoded.id == "msg_2")
        #expect(decoded.method == "test.empty")
        #expect(decoded.payload == nil)
        #expect(decoded.kind == .response)
    }

    @Test("모든 MessageKind 값이 올바르게 직렬화된다",
          arguments: [
              BridgeMessage.MessageKind.request,
              BridgeMessage.MessageKind.response,
              BridgeMessage.MessageKind.nativeEvent,
              BridgeMessage.MessageKind.error,
              BridgeMessage.MessageKind.webEvent
          ])
    func messageKindRoundTrip(kind: BridgeMessage.MessageKind) throws {
        let message = BridgeMessage(
            id: "msg_kind",
            method: "test.kind",
            payload: nil,
            kind: kind
        )

        let data = try encoder.encode(message)
        let decoded = try decoder.decode(BridgeMessage.self, from: data)

        #expect(decoded.kind == kind)
    }

    @Test("MessageKind의 rawValue가 올바르다")
    func messageKindRawValues() {
        #expect(BridgeMessage.MessageKind.request.rawValue == "request")
        #expect(BridgeMessage.MessageKind.response.rawValue == "response")
        #expect(BridgeMessage.MessageKind.nativeEvent.rawValue == "nativeEvent")
        #expect(BridgeMessage.MessageKind.error.rawValue == "error")
        #expect(BridgeMessage.MessageKind.webEvent.rawValue == "webEvent")
    }
}
