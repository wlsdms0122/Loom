import Testing
import Foundation
import Core
import Bridge
import Plugin
@testable import Loom
import LoomTestKit

/// LoomPluginContext.emit()의 동작을 검증한다.
@Suite("LoomPluginContext 테스트")
struct LoomPluginContextTests {
    // MARK: - Property

    private let transport: MockBridgeTransport
    private let bridge: BridgeActor
    private let context: LoomPluginContext

    // MARK: - Initializer

    init() {
        transport = MockBridgeTransport()
        bridge = BridgeActor(transport: transport)
        context = LoomPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger(),
            bridge: bridge
        )
    }

    // MARK: - Tests

    @Test("emit은 JSON 문자열을 이중 인코딩하지 않고 그대로 payload에 담는다")
    func emitPreservesJSONPayload() async throws {
        let json = "{\"msg\":\"hello\"}"

        try await context.emit(event: "test.event", data: json)

        let sentData = transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let message = try extractBridgeMessage(from: data)

        #expect(message.method == "test.event")
        #expect(message.kind == .nativeEvent)

        let payloadString = try #require(message.payload)
        #expect(payloadString == json)
    }

    @Test("emit은 빈 JSON 객체를 올바르게 전달한다")
    func emitEmptyJSON() async throws {
        let json = "{}"

        try await context.emit(event: "empty.event", data: json)

        let sentData = transport.sentData
        let data = try #require(sentData.first)
        let message = try extractBridgeMessage(from: data)

        let payloadString = try #require(message.payload)
        #expect(payloadString == json)
    }

    @Test("emit은 중첩된 JSON을 이중 인코딩하지 않는다")
    func emitNestedJSON() async throws {
        let json = "{\"user\":{\"name\":\"Loom\",\"age\":1}}"

        try await context.emit(event: "nested.event", data: json)

        let sentData = transport.sentData
        let data = try #require(sentData.first)
        let message = try extractBridgeMessage(from: data)

        let payloadString = try #require(message.payload)
        #expect(payloadString == json)
    }

    @Test("emit이 생성하는 메시지의 kind는 nativeEvent이다")
    func emitMessageKindIsNativeEvent() async throws {
        try await context.emit(event: "kind.test", data: "{}")

        let sentData = transport.sentData
        let data = try #require(sentData.first)
        let message = try extractBridgeMessage(from: data)

        #expect(message.kind == .nativeEvent)
    }

    @Test("emit을 여러 번 호출하면 각각 독립적인 메시지가 전송된다")
    func emitMultipleTimes() async throws {
        try await context.emit(event: "event.a", data: "{\"n\":1}")
        try await context.emit(event: "event.b", data: "{\"n\":2}")

        let sentData = transport.sentData
        #expect(sentData.count == 2)

        let messageA = try extractBridgeMessage(from: sentData[0])
        let messageB = try extractBridgeMessage(from: sentData[1])

        #expect(messageA.method == "event.a")
        #expect(messageB.method == "event.b")
        #expect(messageA.id != messageB.id)

        let payloadA = try #require(messageA.payload)
        let payloadB = try #require(messageB.payload)
        #expect(payloadA == "{\"n\":1}")
        #expect(payloadB == "{\"n\":2}")
    }

    // MARK: - Encodable Emit Tests

    @Test("Encodable emit은 구조체를 JSON 문자열로 직렬화하여 전송한다")
    func emitEncodableStruct() async throws {
        struct UserEvent: Codable, Sendable {
            let name: String
            let count: Int
        }
        let event = UserEvent(name: "Loom", count: 42)

        try await context.emit(event: "user.event", data: event)

        let sentData = transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let message = try extractBridgeMessage(from: data)

        #expect(message.method == "user.event")
        #expect(message.kind == .nativeEvent)

        let payloadString = try #require(message.payload)
        let payloadData = Data(payloadString.utf8)
        let decoded = try JSONDecoder().decode(UserEvent.self, from: payloadData)
        #expect(decoded.name == "Loom")
        #expect(decoded.count == 42)
    }

    @Test("Encodable emit은 배열을 JSON으로 직렬화하여 전송한다")
    func emitEncodableArray() async throws {
        let items = [1, 2, 3]

        try await context.emit(event: "array.event", data: items)

        let sentData = transport.sentData
        let data = try #require(sentData.first)
        let message = try extractBridgeMessage(from: data)

        let payloadString = try #require(message.payload)
        let payloadData = Data(payloadString.utf8)
        let decoded = try JSONDecoder().decode([Int].self, from: payloadData)
        #expect(decoded == [1, 2, 3])
    }
}

// MARK: - Test Helper

/// Transport가 전송한 Data에서 BridgeMessage를 추출한다.
private func extractBridgeMessage(from data: Data) throws -> BridgeMessage {
    try JSONDecoder().decode(BridgeMessage.self, from: data)
}
