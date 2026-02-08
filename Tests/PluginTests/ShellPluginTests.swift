import Testing
import Foundation
@testable import Core
@testable import Plugin
import Platform
import LoomTestKit

@Suite("ShellPlugin 테스트")
struct ShellPluginTests {
    // MARK: - Property

    private let plugin: ShellPlugin
    private let stubShell: StubShell

    // MARK: - Initializer

    init() async throws {
        let container = StubContainer()
        let stub = StubShell()
        let shell: any Shell = stub
        await container.register((any Shell).self, scope: .singleton) { shell }
        let context = MockPluginContext(
            container: container,
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        // SecurityPolicy 필수이므로 /tmp, /private/tmp을 허용하는 샌드박스를 사용한다.
        let sandbox = PathSandbox(allowedDirectories: ["/tmp", "/private/tmp"])
        let p = ShellPlugin(securityPolicy: sandbox)
        try await p.initialize(context: context)
        self.plugin = p
        self.stubShell = stub
    }

    // MARK: - Tests

    @Test("플러그인 이름이 shell이다")
    func name() {
        #expect(plugin.name == "shell")
    }

    @Test("메서드가 2개이다")
    func methodCount() async {
        #expect(await plugin.methods().count == 2)
    }

    @Test("openURL 메서드가 존재한다")
    func hasOpenURLMethod() async {
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "openURL" }
        #expect(method != nil)
    }

    @Test("openPath 메서드가 존재한다")
    func hasOpenPathMethod() async {
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "openPath" }
        #expect(method != nil)
    }

    @Test("openURL에 유효한 URL을 전달하면 빈 JSON을 반환한다")
    func openURLValid() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        let payload = """
        {"url":"https://www.apple.com"}
        """
        let result = try await method.handler(payload)
        #expect(result == "{}")

        let expectedURL = try #require(URL(string: "https://www.apple.com"))
        #expect(stubShell.openedURLs == [expectedURL])
    }

    @Test("openURL에 잘못된 URL을 전달하면 invalidArguments 에러가 발생한다")
    func openURLInvalidURL() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        let payload = """
        {"url":""}
        """
        await #expect(throws: PluginError.self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("openURL에 잘못된 JSON을 전달하면 에러가 발생한다")
    func openURLInvalidJSON() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("invalid json")
        }
    }

    @Test("openPath에 유효한 경로를 전달하면 빈 JSON을 반환한다")
    func openPathValid() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openPath" })

        let payload = """
        {"path":"/tmp"}
        """
        let result = try await method.handler(payload)
        #expect(result == "{}")
        #expect(stubShell.openedPaths == ["/tmp"])
    }

    @Test("openPath에 잘못된 JSON을 전달하면 에러가 발생한다")
    func openPathInvalidJSON() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openPath" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("invalid json")
        }
    }

    @Test("URLArgs 디코딩이 정상 동작한다")
    func decodeURLArgs() throws {
        let json = """
        {"url":"https://example.com"}
        """
        let args = try JSONDecoder().decode(
            TestURLArgs.self,
            from: Data(json.utf8)
        )
        #expect(args.url == "https://example.com")
    }

    @Test("URLArgs에 url이 없으면 디코딩 에러가 발생한다")
    func decodeURLArgsMissingURL() throws {
        let json = "{}"
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(
                TestURLArgs.self,
                from: Data(json.utf8)
            )
        }
    }

    @Test("PathArgs 디코딩이 정상 동작한다")
    func decodePathArgs() throws {
        let json = """
        {"path":"/Users/test/Documents"}
        """
        let args = try JSONDecoder().decode(
            PathArgs.self,
            from: Data(json.utf8)
        )
        #expect(args.path == "/Users/test/Documents")
    }

    @Test("PathArgs에 path가 없으면 디코딩 에러가 발생한다")
    func decodePathArgsMissingPath() throws {
        let json = "{}"
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(
                PathArgs.self,
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
        let sandbox = PathSandbox(allowedDirectories: ["/tmp"])
        let p = ShellPlugin(securityPolicy: sandbox)
        try await p.initialize(context: context)
    }

    @Test("dispose가 에러 없이 완료된다")
    func disposeSucceeds() async {
        await plugin.dispose()
    }

    @Test("메서드 이름이 올바른 순서로 반환된다")
    func methodNames() async {
        let names = await plugin.methods().map(\.name)
        #expect(names == ["openURL", "openPath"])
    }

    // MARK: - URL Scheme Validation

    @Test("openURL에 file 스킴을 전달하면 blockedURLScheme 에러가 발생한다")
    func openURLBlocksFileScheme() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        let payload = """
        {"url":"file:///etc/passwd"}
        """
        await #expect(throws: PluginError.self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("openURL에 javascript 스킴을 전달하면 blockedURLScheme 에러가 발생한다")
    func openURLBlocksJavascriptScheme() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        let payload = """
        {"url":"javascript:alert(1)"}
        """
        await #expect(throws: PluginError.self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("openURL에 http 스킴을 전달하면 스킴 에러가 발생하지 않는다")
    func openURLAllowsHTTPScheme() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        let payload = """
        {"url":"http://example.com"}
        """
        let result = try await method.handler(payload)
        #expect(result == "{}")
    }

    @Test("openURL에 https 스킴을 전달하면 스킴 에러가 발생하지 않는다")
    func openURLAllowsHTTPSScheme() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        let payload = """
        {"url":"https://example.com"}
        """
        let result = try await method.handler(payload)
        #expect(result == "{}")
    }

    @Test("openURL에 tel 스킴을 전달하면 blockedURLScheme 에러가 발생한다")
    func openURLBlocksTelScheme() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        let payload = """
        {"url":"tel:+1234567890"}
        """
        await #expect(throws: PluginError.self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("openURL에 커스텀 스킴을 전달하면 blockedURLScheme 에러가 발생한다")
    func openURLBlocksCustomScheme() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        let payload = """
        {"url":"myapp://deeplink"}
        """
        await #expect(throws: PluginError.self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("initialize로 컨테이너에서 URLSchemeWhitelist를 주입받을 수 있다")
    func initializeWithCustomWhitelist() async throws {
        let container = StubContainer()
        let shell: any Shell = StubShell()
        await container.register(URLSchemeWhitelist.self) {
            URLSchemeWhitelist(schemes: ["http", "https", "myapp"])
        }
        await container.register((any Shell).self, scope: .singleton) { shell }

        let context = MockPluginContext(
            container: container,
            eventBus: StubEventBus(),
            logger: StubLogger()
        )

        let sandbox = PathSandbox(allowedDirectories: ["/tmp"])
        let customPlugin = ShellPlugin(securityPolicy: sandbox)
        try await customPlugin.initialize(context: context)

        let methods = await customPlugin.methods()
        let method = try #require(methods.first { $0.name == "openURL" })

        // myapp 스킴이 허용되어야 한다
        let payload = """
        {"url":"myapp://deeplink"}
        """
        let result = try await method.handler(payload)
        #expect(result == "{}")
    }

    // MARK: - Path Validation

    @Test("openPath에 허용되지 않은 경로를 전달하면 blockedPath 에러가 발생한다")
    func openPathBlocksDisallowedPath() async throws {
        let sandbox = PathSandbox(allowedDirectories: ["/tmp"])
        let sandboxedPlugin = try await Self.makePlugin(securityPolicy: sandbox)

        let methods = await sandboxedPlugin.methods()
        let method = try #require(methods.first { $0.name == "openPath" })

        let payload = """
        {"path":"/etc/passwd"}
        """
        await #expect(throws: PluginError.blockedPath("/etc/passwd")) {
            _ = try await method.handler(payload)
        }
    }

    @Test("openPath에 허용된 경로를 전달하면 빈 JSON을 반환한다")
    func openPathAllowsAllowedPath() async throws {
        // /tmp은 macOS에서 /private/tmp의 심볼릭 링크이므로 resolved 경로를 사용한다.
        let tmpPath = resolvedTmpPath()
        let sandbox = PathSandbox(allowedDirectories: [tmpPath])
        let sandboxedPlugin = try await Self.makePlugin(securityPolicy: sandbox)

        let methods = await sandboxedPlugin.methods()
        let method = try #require(methods.first { $0.name == "openPath" })

        let payload = """
        {"path":"\(tmpPath)"}
        """
        let result = try await method.handler(payload)
        #expect(result == "{}")
    }

    // MARK: - Helper

    private static func makePlugin(
        securityPolicy: any SecurityPolicy
    ) async throws -> ShellPlugin {
        let container = StubContainer()
        let shell: any Shell = StubShell()
        await container.register((any Shell).self, scope: .singleton) { shell }
        let context = MockPluginContext(
            container: container,
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        let p = ShellPlugin(securityPolicy: securityPolicy)
        try await p.initialize(context: context)
        return p
    }

    /// /tmp의 심볼릭 링크를 해석한 실제 경로를 반환한다.
    private func resolvedTmpPath() -> String {
        if let resolved = realpath("/tmp", nil) {
            let path = String(cString: resolved)
            free(resolved)
            return path
        }
        return "/tmp"
    }
}

// MARK: - Test Helper

/// ShellPlugin 내부의 URLArgs와 동일한 구조. private 타입이므로 테스트용으로 재정의한다.
private struct TestURLArgs: Codable {
    let url: String
}
