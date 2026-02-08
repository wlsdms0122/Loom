import Testing
import Foundation
import os
@testable import Plugin

// MARK: - Test DTOs

private struct GreetArgs: Codable, Sendable {
    let name: String
}

private struct GreetResult: Codable, Sendable {
    let message: String
}

// MARK: - PluginMethod 타입-세이프 convenience init 테스트

@Suite("PluginMethod 타입-세이프 convenience init 테스트")
struct PluginMethodTypeSafeTests {
    // MARK: - Args + Result

    @Test("유효한 Decodable 인자를 전달하면 올바른 Result를 반환한다")
    func typeSafeArgsAndResult() async throws {
        let method = PluginMethod(name: "greet") { (args: GreetArgs) -> GreetResult in
            GreetResult(message: "Hello, \(args.name)!")
        }

        let payload = """
        {"name":"Loom"}
        """
        let result = try await method.handler(payload)
        let decoded = try JSONDecoder().decode(GreetResult.self, from: Data(result.utf8))

        #expect(method.name == "greet")
        #expect(decoded.message == "Hello, Loom!")
    }

    @Test("유효하지 않은 JSON을 전달하면 디코딩 에러가 발생한다")
    func typeSafeInvalidJSON() async {
        let method = PluginMethod(name: "greet") { (args: GreetArgs) -> GreetResult in
            GreetResult(message: "Hello, \(args.name)!")
        }

        let invalidPayload = "not valid json"
        await #expect(throws: DecodingError.self) {
            _ = try await method.handler(invalidPayload)
        }
    }

    @Test("필수 필드가 누락된 JSON을 전달하면 디코딩 에러가 발생한다")
    func typeSafeMissingField() async {
        let method = PluginMethod(name: "greet") { (args: GreetArgs) -> GreetResult in
            GreetResult(message: "Hello, \(args.name)!")
        }

        let missingFieldPayload = """
        {"age":30}
        """
        await #expect(throws: DecodingError.self) {
            _ = try await method.handler(missingFieldPayload)
        }
    }

    @Test("Dictionary 타입을 Result로 사용할 수 있다")
    func typeSafeDictionaryResult() async throws {
        let method = PluginMethod(name: "count") { (args: GreetArgs) -> [String: Int] in
            ["length": args.name.count]
        }

        let payload = """
        {"name":"Swift"}
        """
        let result = try await method.handler(payload)
        let decoded = try JSONDecoder().decode([String: Int].self, from: Data(result.utf8))

        #expect(decoded["length"] == 5)
    }

    // MARK: - No Args, Result Only

    @Test("인자 없는 핸들러가 올바른 Result를 반환한다")
    func noArgsWithResult() async throws {
        let method = PluginMethod(name: "version") { () -> [String: String] in
            ["version": "1.0.0"]
        }

        let result = try await method.handler("")
        let decoded = try JSONDecoder().decode([String: String].self, from: Data(result.utf8))

        #expect(method.name == "version")
        #expect(decoded["version"] == "1.0.0")
    }

    @Test("인자 없는 핸들러에 빈 문자열을 전달해도 정상 동작한다")
    func noArgsIgnoresPayload() async throws {
        let method = PluginMethod(name: "ping") { () -> [String: String] in
            ["status": "pong"]
        }

        let result = try await method.handler("{\"ignored\":true}")
        let decoded = try JSONDecoder().decode([String: String].self, from: Data(result.utf8))

        #expect(decoded["status"] == "pong")
    }

    // MARK: - Error Propagation

    @Test("핸들러에서 발생한 에러가 그대로 전파된다")
    func handlerErrorPropagation() async {
        let method = PluginMethod(name: "fail") { (args: GreetArgs) -> GreetResult in
            throw PluginError.custom("test error")
        }

        let payload = """
        {"name":"test"}
        """
        await #expect(throws: PluginError.self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("인자 없는 핸들러에서 발생한 에러가 그대로 전파된다")
    func noArgsHandlerErrorPropagation() async {
        let method = PluginMethod(name: "fail") { () -> [String: String] in
            throw PluginError.unsupportedPlatform
        }

        await #expect(throws: PluginError.self) {
            _ = try await method.handler("")
        }
    }

    // MARK: - Args + Void

    @Test("인자를 받아 Void를 반환하는 핸들러가 빈 JSON을 반환한다")
    func argsWithVoidReturn() async throws {
        let captured = OSAllocatedUnfairLock(initialState: "")
        let method = PluginMethod(name: "log") { [captured] (args: GreetArgs) in
            captured.withLock { $0 = args.name }
        }

        let result = try await method.handler("{\"name\":\"Loom\"}")
        #expect(result == "{}")
        #expect(captured.withLock { $0 } == "Loom")
    }

    @Test("인자 없이 Void를 반환하는 핸들러가 빈 JSON을 반환한다")
    func noArgsVoidReturn() async throws {
        let called = OSAllocatedUnfairLock(initialState: false)
        let method = PluginMethod(name: "noop") { [called] () in
            called.withLock { $0 = true }
        }

        let result = try await method.handler("")
        #expect(result == "{}")
        #expect(called.withLock { $0 } == true)
    }

    @Test("Void 핸들러에서 에러가 전파된다")
    func voidHandlerErrorPropagation() async {
        let method = PluginMethod(name: "fail") { (args: GreetArgs) in
            throw PluginError.invalidArguments
        }

        await #expect(throws: PluginError.self) {
            _ = try await method.handler("{\"name\":\"test\"}")
        }
    }

    // MARK: - String Handler Init

    @Test("기존 String 핸들러 init이 여전히 동작한다")
    func stringHandlerInit() async throws {
        let method = PluginMethod(name: "echo") { payload in
            payload
        }

        let result = try await method.handler("hello")
        #expect(result == "hello")
    }
}
