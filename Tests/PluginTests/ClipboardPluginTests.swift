import Testing
import Foundation
@testable import Plugin
import Platform
import LoomTestKit

@Suite("ClipboardPlugin 테스트", .serialized)
struct ClipboardPluginTests {
    // MARK: - Property

    private let plugin: ClipboardPlugin

    // MARK: - Initializer

    init() async throws {
        let container = StubContainer()
        let clipboard: any Clipboard = StubClipboard()
        await container.register((any Clipboard).self, scope: .singleton) { clipboard }
        let context = MockPluginContext(
            container: container,
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        let p = ClipboardPlugin()
        try await p.initialize(context: context)
        self.plugin = p
    }

    // MARK: - Tests

    @Test("플러그인 이름이 clipboard이다")
    func name() {
        #expect(plugin.name == "clipboard")
    }

    @Test("메서드가 2개이다")
    func methodCount() async {
        #expect(await plugin.methods().count == 2)
    }

    @Test("readText 메서드가 존재한다")
    func hasReadTextMethod() async {
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "readText" }
        #expect(method != nil)
    }

    @Test("writeText 메서드가 존재한다")
    func hasWriteTextMethod() async {
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "writeText" }
        #expect(method != nil)
    }

    @Test("텍스트를 쓰고 읽을 수 있다")
    func writeAndReadText() async throws {
        let methods = await plugin.methods()
        let writeMethod = try #require(methods.first { $0.name == "writeText" })
        let readMethod = try #require(methods.first { $0.name == "readText" })

        let testText = "Loom ClipboardPlugin 테스트 \(UUID().uuidString)"
        let writePayload = """
        {"text":"\(testText)"}
        """
        _ = try await writeMethod.handler(writePayload)

        let readResult = try await readMethod.handler("{}")
        let decoded = try JSONDecoder().decode(
            [String: String].self,
            from: Data(readResult.utf8)
        )
        #expect(decoded["text"] == testText)
    }

    @Test("writeText에 잘못된 JSON을 전달하면 에러가 발생한다")
    func writeTextInvalidPayload() async throws {
        let methods = await plugin.methods()
        let writeMethod = try #require(methods.first { $0.name == "writeText" })

        await #expect(throws: (any Error).self) {
            _ = try await writeMethod.handler("invalid json")
        }
    }

    @Test("readText는 항상 text 키가 포함된 JSON을 반환한다")
    func readTextReturnsTextKey() async throws {
        let methods = await plugin.methods()
        let readMethod = try #require(methods.first { $0.name == "readText" })

        let result = try await readMethod.handler("{}")
        let decoded = try JSONDecoder().decode(
            [String: String].self,
            from: Data(result.utf8)
        )
        #expect(decoded.keys.contains("text"))
    }

    @Test("writeText는 빈 JSON을 반환한다")
    func writeTextReturnsEmptyJSON() async throws {
        let methods = await plugin.methods()
        let writeMethod = try #require(methods.first { $0.name == "writeText" })

        let payload = """
        {"text":"test"}
        """
        let result = try await writeMethod.handler(payload)
        #expect(result == "{}")
    }

    @Test("빈 문자열을 클립보드에 쓸 수 있다")
    func writeEmptyText() async throws {
        let methods = await plugin.methods()
        let writeMethod = try #require(methods.first { $0.name == "writeText" })
        let readMethod = try #require(methods.first { $0.name == "readText" })

        let payload = """
        {"text":""}
        """
        _ = try await writeMethod.handler(payload)

        let readResult = try await readMethod.handler("{}")
        let decoded = try JSONDecoder().decode(
            [String: String].self,
            from: Data(readResult.utf8)
        )
        #expect(decoded["text"] == "")
    }

    @Test("ClipboardWriteArgs 디코딩이 정상 동작한다")
    func decodeClipboardWriteArgs() throws {
        let json = """
        {"text":"hello clipboard"}
        """
        let args = try JSONDecoder().decode(
            TestClipboardWriteArgs.self,
            from: Data(json.utf8)
        )
        #expect(args.text == "hello clipboard")
    }

    @Test("ClipboardWriteArgs에 text가 없으면 디코딩 에러가 발생한다")
    func decodeClipboardWriteArgsMissingText() throws {
        let json = "{}"
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(
                TestClipboardWriteArgs.self,
                from: Data(json.utf8)
            )
        }
    }

    @Test("initialize가 에러 없이 완료된다")
    func initializeSucceeds() async throws {
        let context = MockPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        let p = ClipboardPlugin()
        try await p.initialize(context: context)
    }

    @Test("dispose가 에러 없이 완료된다")
    func disposeSucceeds() async {
        await plugin.dispose()
    }

    @Test("메서드 이름이 올바른 순서로 반환된다")
    func methodNames() async {
        let names = await plugin.methods().map(\.name)
        #expect(names == ["readText", "writeText"])
    }
}

// MARK: - Test Helper

/// ClipboardPlugin 내부의 ClipboardWriteArgs와 동일한 구조. private 타입이므로 테스트용으로 재정의한다.
private struct TestClipboardWriteArgs: Codable {
    let text: String
}
