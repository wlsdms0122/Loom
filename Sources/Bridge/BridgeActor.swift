import Foundation
import Core

/// 에러 응답에 포함되는 구조화된 페이로드.
struct ErrorPayload: Codable, Sendable {
    // MARK: - Property

    /// 에러 코드.
    let code: String

    /// 에러 메시지.
    let message: String

    /// 플러그인 이름 (있을 경우).
    let plugin: String?

    /// 메서드 이름 (있을 경우).
    let method: String?

    // MARK: - Initializer

    init(code: String, message: String, plugin: String? = nil, method: String? = nil) {
        self.code = code
        self.message = message
        self.plugin = plugin
        self.method = method
    }
}

/// Bridge의 기본 구현. Actor로 핸들러 레지스트리를 격리한다.
public actor BridgeActor: Bridge {
    // MARK: - Property

    private var handlers: [String: @Sendable (String?) async throws -> String?] = [:]
    private var eventHandlers: [String: [@Sendable (String?) async -> Void]] = [:]
    private let transport: any BridgeTransport
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger: (any Logger)?

    // MARK: - Initializer

    public init(transport: any BridgeTransport, logger: (any Logger)? = nil) {
        self.transport = transport
        self.logger = logger
    }

    // MARK: - Public

    public func register(method: String, handler: @escaping @Sendable (String?) async throws -> String?) {
        handlers[method] = handler
    }

    public func unregister(method: String) {
        handlers.removeValue(forKey: method)
    }

    /// 웹에서 보낸 단방향 이벤트에 대한 핸들러를 등록한다.
    ///
    /// - Parameters:
    ///   - name: 이벤트 이름.
    ///   - handler: 이벤트 데이터를 받는 비동기 핸들러.
    public func onEvent(name: String, handler: @escaping @Sendable (String?) async -> Void) {
        eventHandlers[name, default: []].append(handler)
    }

    /// 등록된 메서드 핸들러를 모두 제거한다.
    public func removeAllHandlers() {
        handlers.removeAll()
    }

    /// 등록된 이벤트 핸들러를 모두 제거한다.
    public func removeAllEventHandlers() {
        eventHandlers.removeAll()
    }

    public func receive(_ rawMessage: String) async {
        guard let data = rawMessage.data(using: .utf8) else {
            logError("Bridge 메시지를 UTF-8로 인코딩할 수 없음")
            return
        }
        let message: BridgeMessage
        do {
            message = try decoder.decode(BridgeMessage.self, from: data)
        } catch {
            #if DEBUG
            let preview = String(rawMessage.prefix(200))
            logError("Bridge 메시지 JSON 디코딩 실패: \(preview)")
            #else
            logError("Bridge 메시지 JSON 디코딩 실패")
            #endif
            return
        }

        if message.kind == .webEvent {
            let handlers = eventHandlers[message.method] ?? []
            for handler in handlers {
                await handler(message.payload)
            }
            return
        }
        guard message.kind == .request else { return }
        guard let handler = handlers[message.method] else {
            let payload = ErrorPayload(
                code: "METHOD_NOT_FOUND",
                message: "Method not found: \(message.method)",
                plugin: nil,
                method: message.method
            )
            await sendError(payload: payload, for: message)
            return
        }
        do {
            let result = try await handler(message.payload)
            let response = BridgeMessage(
                id: message.id,
                method: message.method,
                payload: result,
                kind: .response
            )
            do {
                try await send(response)
            } catch {
                logError("Failed to send response for method '\(message.method)': \(error.localizedDescription)")
            }
        } catch {
            let payload = ErrorPayload(
                code: "HANDLER_ERROR",
                message: error.localizedDescription,
                plugin: nil,
                method: message.method
            )
            await sendError(payload: payload, for: message)
        }
    }

    public func send(_ message: BridgeMessage) async throws {
        let data = try encoder.encode(message)
        try await transport.send(data)
    }

    // MARK: - Private

    /// 구조화된 에러 페이로드를 인코딩하여 에러 메시지를 전송한다.
    private func sendError(payload: ErrorPayload, for message: BridgeMessage) async {
        do {
            let errorData = try encoder.encode(payload)
            let errorString = String(data: errorData, encoding: .utf8)
            let errorMsg = BridgeMessage(
                id: message.id,
                method: message.method,
                payload: errorString,
                kind: .error
            )
            try await send(errorMsg)
        } catch {
            logError("Failed to send error response for method '\(message.method)': \(error.localizedDescription)")
        }
    }

    /// 로거가 있으면 로거로, 없으면 콘솔에 에러를 출력한다.
    private nonisolated func logError(_ message: String, file: String = #file, line: Int = #line) {
        if let logger {
            logger.error(message, file: file, line: line)
        } else {
            print("[ERROR] \(message)")
        }
    }
}
