import Foundation

/// 플러그인이 노출하는 개별 메서드를 나타내는 구조체.
public struct PluginMethod: Sendable {
    // MARK: - Property

    /// 메서드 이름.
    public let name: String

    /// 메서드 핸들러. JSON 문자열을 받아 JSON 문자열을 반환한다.
    public let handler: @Sendable (String) async throws -> String

    // MARK: - Initializer

    public init(name: String, handler: @escaping @Sendable (String) async throws -> String) {
        self.name = name
        self.handler = handler
    }
}

// MARK: - Type-Safe Convenience Initializers

extension PluginMethod {
    // MARK: Encoding Helper

    /// Encodable 값을 JSON 문자열로 인코딩한다.
    private static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        guard let json = String(data: data, encoding: .utf8) else {
            throw PluginError.encodingFailed
        }
        return json
    }

    // MARK: Convenience Initializers

    /// 타입-세이프 convenience init. JSON 디코딩/인코딩을 자동으로 처리한다.
    /// - Parameters:
    ///   - name: 메서드 이름.
    ///   - handler: Decodable 인자를 받아 Encodable 결과를 반환하는 핸들러.
    public init<Args: Decodable & Sendable, Result: Encodable & Sendable>(
        name: String,
        handler: @escaping @Sendable (Args) async throws -> Result
    ) {
        self.name = name
        self.handler = { payload in
            let args = try JSONDecoder().decode(Args.self, from: Data(payload.utf8))
            let result = try await handler(args)
            return try Self.encode(result)
        }
    }

    /// 인자 없는 타입-세이프 convenience init. JSON 인코딩을 자동으로 처리한다.
    /// - Parameters:
    ///   - name: 메서드 이름.
    ///   - handler: 인자 없이 Encodable 결과를 반환하는 핸들러.
    public init<Result: Encodable & Sendable>(
        name: String,
        handler: @escaping @Sendable () async throws -> Result
    ) {
        self.name = name
        self.handler = { _ in
            let result = try await handler()
            return try Self.encode(result)
        }
    }

    /// Void 반환 타입-세이프 convenience init. 인자를 디코딩하고 핸들러를 실행한 뒤 빈 성공 응답을 반환한다.
    /// - Parameters:
    ///   - name: 메서드 이름.
    ///   - handler: Decodable 인자를 받아 Void를 반환하는 핸들러.
    public init<Args: Decodable & Sendable>(
        name: String,
        handler: @escaping @Sendable (Args) async throws -> Void
    ) {
        self.name = name
        self.handler = { payload in
            let args = try JSONDecoder().decode(Args.self, from: Data(payload.utf8))
            try await handler(args)
            return "{}"
        }
    }

    /// 인자 없는 Void 반환 convenience init. 핸들러를 실행한 뒤 빈 성공 응답을 반환한다.
    /// - Parameters:
    ///   - name: 메서드 이름.
    ///   - handler: 인자 없이 Void를 반환하는 핸들러.
    public init(
        name: String,
        handler: @escaping @Sendable () async throws -> Void
    ) {
        self.name = name
        self.handler = { _ in
            try await handler()
            return "{}"
        }
    }
}
