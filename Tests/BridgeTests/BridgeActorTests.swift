import Foundation
import Testing
@testable import Bridge
@testable import Core
import LoomTestKit

/// BridgeActor의 핸들러 등록, 메시지 수신, 전송을 검증한다.
@Suite("BridgeActor")
struct BridgeActorTests {
    // MARK: - Property

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Public

    @Test("핸들러를 등록하고 요청을 처리하면 응답이 전송된다")
    func registerAndReceive() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let responsePayload = "{\"result\":\"ok\"}"
        await bridge.register(method: "test.echo") { _ in responsePayload }

        let request = BridgeMessage(
            id: "msg_1",
            method: "test.echo",
            payload: nil,
            kind: .request
        )
        await bridge.receive(try toRawMessage(request))

        let sentData = await transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let sent = try decoder.decode(BridgeMessage.self, from: data)
        #expect(sent.id == "msg_1")
        #expect(sent.method == "test.echo")
        #expect(sent.kind == .response)
        #expect(sent.payload == responsePayload)
    }

    @Test("등록되지 않은 메서드를 호출하면 에러 응답이 전송된다")
    func unregisteredMethodSendsError() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let request = BridgeMessage(
            id: "msg_2",
            method: "unknown.method",
            payload: nil,
            kind: .request
        )
        await bridge.receive(try toRawMessage(request))

        let sentData = await transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let sent = try decoder.decode(BridgeMessage.self, from: data)
        #expect(sent.id == "msg_2")
        #expect(sent.kind == .error)
    }

    @Test("핸들러를 해제하면 에러 응답이 전송된다")
    func unregisterRemovesHandler() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        await bridge.register(method: "test.remove") { _ in nil }
        await bridge.unregister(method: "test.remove")

        let request = BridgeMessage(
            id: "msg_3",
            method: "test.remove",
            payload: nil,
            kind: .request
        )
        await bridge.receive(try toRawMessage(request))

        let sentData = await transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let sent = try decoder.decode(BridgeMessage.self, from: data)
        #expect(sent.kind == .error)
    }

    @Test("핸들러가 에러를 던지면 에러 응답이 전송된다")
    func handlerErrorSendsErrorResponse() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        await bridge.register(method: "test.fail") { _ in
            throw TestError.intentional
        }

        let request = BridgeMessage(
            id: "msg_4",
            method: "test.fail",
            payload: nil,
            kind: .request
        )
        await bridge.receive(try toRawMessage(request))

        let sentData = await transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let sent = try decoder.decode(BridgeMessage.self, from: data)
        #expect(sent.id == "msg_4")
        #expect(sent.kind == .error)
    }

    @Test("request가 아닌 메시지는 무시된다")
    func nonRequestMessageIgnored() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let event = BridgeMessage(
            id: "msg_5",
            method: "test.event",
            payload: nil,
            kind: .nativeEvent
        )
        await bridge.receive(try toRawMessage(event))

        let sentData = await transport.sentData
        #expect(sentData.isEmpty)
    }

    @Test("send 메서드가 올바른 Data를 전송한다")
    func sendOutputsData() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let message = BridgeMessage(
            id: "msg_6",
            method: "test.send",
            payload: nil,
            kind: .response
        )
        try await bridge.send(message)

        let sentData = await transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let decoded = try decoder.decode(BridgeMessage.self, from: data)
        #expect(decoded.id == "msg_6")
        #expect(decoded.method == "test.send")
        #expect(decoded.kind == .response)
    }

    @Test("에러 전송 실패 시 로거에 기록된다")
    func errorSendFailureIsLogged() async throws {
        let transport = FailingBridgeTransport()
        let logger = SpyLogger()
        let bridge = BridgeActor(transport: transport, logger: logger)

        await bridge.register(method: "test.fail") { _ in
            throw TestError.intentional
        }

        let request = BridgeMessage(
            id: "msg_log_1",
            method: "test.fail",
            payload: nil,
            kind: .request
        )
        await bridge.receive(try toRawMessage(request))

        let entries = logger.entries
        #expect(!entries.isEmpty)

        let errorMessages = entries.filter { $0.level == .error }
        #expect(!errorMessages.isEmpty)

        let firstError = try #require(errorMessages.first)
        #expect(firstError.message.contains("test.fail"))
    }

    @Test("구조화된 에러 페이로드가 전송된다")
    func structuredErrorPayloadSent() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let request = BridgeMessage(
            id: "msg_struct_1",
            method: "nonexistent.method",
            payload: nil,
            kind: .request
        )
        await bridge.receive(try toRawMessage(request))

        let sentData = await transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let sent = try decoder.decode(BridgeMessage.self, from: data)
        #expect(sent.kind == .error)

        let payloadString = try #require(sent.payload)
        let payloadData = Data(payloadString.utf8)
        let errorPayload = try decoder.decode(ErrorPayload.self, from: payloadData)
        #expect(errorPayload.code == "METHOD_NOT_FOUND")
        #expect(errorPayload.message.contains("nonexistent.method"))
        #expect(errorPayload.method == "nonexistent.method")
    }

    @Test("핸들러 에러의 구조화된 페이로드에 HANDLER_ERROR 코드가 포함된다")
    func handlerErrorStructuredPayload() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        await bridge.register(method: "test.handler_fail") { _ in
            throw TestError.intentional
        }

        let request = BridgeMessage(
            id: "msg_struct_2",
            method: "test.handler_fail",
            payload: nil,
            kind: .request
        )
        await bridge.receive(try toRawMessage(request))

        let sentData = await transport.sentData
        let data = try #require(sentData.first)
        let sent = try decoder.decode(BridgeMessage.self, from: data)
        let payloadString = try #require(sent.payload)
        let payloadData = Data(payloadString.utf8)
        let errorPayload = try decoder.decode(ErrorPayload.self, from: payloadData)
        #expect(errorPayload.code == "HANDLER_ERROR")
        #expect(errorPayload.method == "test.handler_fail")
    }

    @Test("동시에 다수의 요청을 처리해도 충돌이나 데이터 경합이 발생하지 않는다")
    func concurrentRequestsHandledCorrectly() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let responsePayload = "{\"result\":\"ok\"}"
        await bridge.register(method: "test.concurrent") { _ in responsePayload }

        let requestCount = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<requestCount {
                group.addTask {
                    let request = BridgeMessage(
                        id: "concurrent_\(i)",
                        method: "test.concurrent",
                        payload: nil,
                        kind: .request
                    )
                    let raw = try! JSONEncoder().encode(request)
                    let rawString = String(data: raw, encoding: .utf8)!
                    await bridge.receive(rawString)
                }
            }
        }

        let sentData = await transport.sentData
        #expect(sentData.count == requestCount)

        // Verify all responses are valid and have the correct structure
        var receivedIds = Set<String>()
        for data in sentData {
            let sent = try decoder.decode(BridgeMessage.self, from: data)
            #expect(sent.kind == .response)
            #expect(sent.method == "test.concurrent")
            receivedIds.insert(sent.id)
        }

        // All unique request IDs should be present in responses
        #expect(receivedIds.count == requestCount)
        for i in 0..<requestCount {
            #expect(receivedIds.contains("concurrent_\(i)"))
        }
    }

    @Test("동시에 등록되지 않은 메서드 요청을 처리하면 모두 에러 응답이 전송된다")
    func concurrentUnregisteredMethodRequests() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let requestCount = 50

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<requestCount {
                group.addTask {
                    let request = BridgeMessage(
                        id: "unregistered_\(i)",
                        method: "unknown.method",
                        payload: nil,
                        kind: .request
                    )
                    let raw = try! JSONEncoder().encode(request)
                    let rawString = String(data: raw, encoding: .utf8)!
                    await bridge.receive(rawString)
                }
            }
        }

        let sentData = await transport.sentData
        #expect(sentData.count == requestCount)

        for data in sentData {
            let sent = try decoder.decode(BridgeMessage.self, from: data)
            #expect(sent.kind == .error)
        }
    }

    // MARK: - emit 메시지 처리 테스트

    @Test("emit 메시지가 등록된 이벤트 핸들러를 호출한다")
    func emitMessageCallsEventHandler() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let receivedData = UnsafeSendableBox<String?>(nil)
        await bridge.onEvent(name: "user.action") { data in
            receivedData.value = data
        }

        let payloadString = "{\"key\":\"value\"}"
        let emitMessage = BridgeMessage(
            id: "emit_1",
            method: "user.action",
            payload: payloadString,
            kind: .webEvent
        )
        await bridge.receive(try toRawMessage(emitMessage))

        // 이벤트 핸들러가 호출되었는지 확인
        #expect(receivedData.value != nil)

        // 응답이 전송되지 않았는지 확인 (fire-and-forget)
        let sentData = await transport.sentData
        #expect(sentData.isEmpty)
    }

    @Test("emit 메시지에 핸들러가 없으면 무시된다")
    func emitWithoutHandlerIsIgnored() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let emitMessage = BridgeMessage(
            id: "emit_2",
            method: "unhandled.event",
            payload: nil,
            kind: .webEvent
        )
        await bridge.receive(try toRawMessage(emitMessage))

        // 아무 응답도 전송되지 않았는지 확인
        let sentData = await transport.sentData
        #expect(sentData.isEmpty)
    }

    @Test("emit 메시지가 여러 이벤트 핸들러를 호출한다")
    func emitCallsMultipleEventHandlers() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let callCount = UnsafeSendableBox<Int>(0)
        await bridge.onEvent(name: "multi.event") { _ in
            callCount.value += 1
        }
        await bridge.onEvent(name: "multi.event") { _ in
            callCount.value += 1
        }

        let emitMessage = BridgeMessage(
            id: "emit_3",
            method: "multi.event",
            payload: nil,
            kind: .webEvent
        )
        await bridge.receive(try toRawMessage(emitMessage))

        #expect(callCount.value == 2)

        let sentData = await transport.sentData
        #expect(sentData.isEmpty)
    }

    @Test("동시에 성공과 실패 핸들러 요청을 혼합 처리해도 올바르게 동작한다")
    func concurrentMixedRequests() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let successPayload = "{\"status\":\"success\"}"
        await bridge.register(method: "test.success") { _ in successPayload }
        await bridge.register(method: "test.error") { _ in
            throw TestError.intentional
        }

        let requestCount = 50

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<requestCount {
                group.addTask {
                    let method = i % 2 == 0 ? "test.success" : "test.error"
                    let request = BridgeMessage(
                        id: "mixed_\(i)",
                        method: method,
                        payload: nil,
                        kind: .request
                    )
                    let raw = try! JSONEncoder().encode(request)
                    let rawString = String(data: raw, encoding: .utf8)!
                    await bridge.receive(rawString)
                }
            }
        }

        let sentData = await transport.sentData
        #expect(sentData.count == requestCount)

        var successCount = 0
        var errorCount = 0
        for data in sentData {
            let sent = try decoder.decode(BridgeMessage.self, from: data)
            if sent.kind == .response {
                successCount += 1
            } else if sent.kind == .error {
                errorCount += 1
            }
        }

        #expect(successCount == requestCount / 2)
        #expect(errorCount == requestCount / 2)
    }

    // MARK: - removeAllHandlers / removeAllEventHandlers 테스트

    @Test("removeAllHandlers 호출 후 핸들러가 비어있다")
    func removeAllHandlersClearsHandlers() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let responsePayload = "{\"result\":\"ok\"}"
        await bridge.register(method: "test.a") { _ in responsePayload }
        await bridge.register(method: "test.b") { _ in responsePayload }
        await bridge.register(method: "test.c") { _ in responsePayload }

        // 핸들러를 모두 제거한다.
        await bridge.removeAllHandlers()

        // 제거된 메서드에 요청을 보내면 에러 응답이 전송되어야 한다.
        let request = BridgeMessage(
            id: "removeall_1",
            method: "test.a",
            payload: nil,
            kind: .request
        )
        await bridge.receive(try toRawMessage(request))

        let sentData = await transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let sent = try decoder.decode(BridgeMessage.self, from: data)
        #expect(sent.kind == .error)

        let payloadString = try #require(sent.payload)
        let payloadData = Data(payloadString.utf8)
        let errorPayload = try decoder.decode(ErrorPayload.self, from: payloadData)
        #expect(errorPayload.code == "METHOD_NOT_FOUND")
    }

    @Test("removeAllHandlers 후 여러 메서드 요청이 모두 에러를 반환한다")
    func removeAllHandlersAllMethodsFail() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let responsePayload = "{\"ok\":true}"
        await bridge.register(method: "test.x") { _ in responsePayload }
        await bridge.register(method: "test.y") { _ in responsePayload }

        await bridge.removeAllHandlers()

        // 두 메서드 모두에 요청을 보낸다.
        for (i, method) in ["test.x", "test.y"].enumerated() {
            let request = BridgeMessage(
                id: "removeall_multi_\(i)",
                method: method,
                payload: nil,
                kind: .request
            )
            await bridge.receive(try toRawMessage(request))
        }

        let sentData = await transport.sentData
        #expect(sentData.count == 2)

        for data in sentData {
            let sent = try decoder.decode(BridgeMessage.self, from: data)
            #expect(sent.kind == .error)
        }
    }

    @Test("removeAllEventHandlers 호출 후 이벤트 핸들러가 비어있다")
    func removeAllEventHandlersClearsEventHandlers() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let callCount = UnsafeSendableBox<Int>(0)
        await bridge.onEvent(name: "event.a") { _ in
            callCount.value += 1
        }
        await bridge.onEvent(name: "event.b") { _ in
            callCount.value += 1
        }

        // 이벤트 핸들러를 모두 제거한다.
        await bridge.removeAllEventHandlers()

        // emit 메시지를 보내도 핸들러가 호출되지 않아야 한다.
        let emitA = BridgeMessage(
            id: "removeevt_1",
            method: "event.a",
            payload: nil,
            kind: .webEvent
        )
        let emitB = BridgeMessage(
            id: "removeevt_2",
            method: "event.b",
            payload: nil,
            kind: .webEvent
        )
        await bridge.receive(try toRawMessage(emitA))
        await bridge.receive(try toRawMessage(emitB))

        #expect(callCount.value == 0)

        // 응답도 전송되지 않아야 한다.
        let sentData = await transport.sentData
        #expect(sentData.isEmpty)
    }

    @Test("removeAllHandlers는 이벤트 핸들러에 영향을 주지 않는다")
    func removeAllHandlersDoesNotAffectEventHandlers() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let eventCalled = UnsafeSendableBox<Bool>(false)
        await bridge.onEvent(name: "keep.event") { _ in
            eventCalled.value = true
        }

        let responsePayload = "{\"ok\":true}"
        await bridge.register(method: "remove.method") { _ in responsePayload }

        // 메서드 핸들러만 제거한다.
        await bridge.removeAllHandlers()

        // 이벤트는 여전히 동작해야 한다.
        let emitMessage = BridgeMessage(
            id: "keep_evt_1",
            method: "keep.event",
            payload: nil,
            kind: .webEvent
        )
        await bridge.receive(try toRawMessage(emitMessage))

        #expect(eventCalled.value == true)
    }

    @Test("removeAllEventHandlers는 메서드 핸들러에 영향을 주지 않는다")
    func removeAllEventHandlersDoesNotAffectMethodHandlers() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let responsePayload = "{\"result\":\"kept\"}"
        await bridge.register(method: "keep.method") { _ in responsePayload }

        await bridge.onEvent(name: "remove.event") { _ in }

        // 이벤트 핸들러만 제거한다.
        await bridge.removeAllEventHandlers()

        // 메서드 핸들러는 여전히 동작해야 한다.
        let request = BridgeMessage(
            id: "keep_method_1",
            method: "keep.method",
            payload: nil,
            kind: .request
        )
        await bridge.receive(try toRawMessage(request))

        let sentData = await transport.sentData
        #expect(sentData.count == 1)

        let data = try #require(sentData.first)
        let sent = try decoder.decode(BridgeMessage.self, from: data)
        #expect(sent.kind == .response)
    }

    // MARK: - Private

    /// BridgeMessage를 JSON 문자열로 변환한다.
    private func toRawMessage(_ message: BridgeMessage) throws -> String {
        let data = try encoder.encode(message)
        return String(data: data, encoding: .utf8)!
    }
}

// MARK: - Test Helper

/// 항상 전송에 실패하는 테스트용 전송 계층 구현체.
final class FailingBridgeTransport: BridgeTransport, @unchecked Sendable {
    // MARK: - Public

    func send(_ data: Data) async throws {
        throw TransportError.sendFailed
    }
}

/// 전송 에러.
private enum TransportError: Error {
    case sendFailed
}

/// 테스트용 에러.
private enum TestError: Error {
    case intentional
}

/// 테스트에서 async 클로저에서 값을 캡처하기 위한 Sendable 래퍼.
final class UnsafeSendableBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

