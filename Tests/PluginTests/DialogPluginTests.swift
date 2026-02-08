import Testing
import Foundation
import Core
@testable import Plugin
import Platform
import LoomTestKit

@Suite("DialogPlugin 테스트")
struct DialogPluginTests {
    // MARK: - Property

    private let plugin: DialogPlugin

    // MARK: - Initializer

    init() {
        plugin = DialogPlugin()
    }

    // MARK: - Tests

    @Test("플러그인 이름이 dialog이다")
    func name() {
        #expect(plugin.name == "dialog")
    }

    @Test("메서드가 3개이다")
    func methodCount() async {
        #expect(await plugin.methods().count == 3)
    }

    @Test("openFile 메서드가 존재한다")
    func hasOpenFileMethod() async {
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "openFile" }
        #expect(method != nil)
    }

    @Test("saveFile 메서드가 존재한다")
    func hasSaveFileMethod() async {
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "saveFile" }
        #expect(method != nil)
    }

    @Test("showAlert 메서드가 존재한다")
    func hasShowAlertMethod() async {
        let methods = await plugin.methods()
        let method = methods.first { $0.name == "showAlert" }
        #expect(method != nil)
    }

    @Test("openFile에 잘못된 JSON을 전달하면 에러가 발생한다")
    func openFileInvalidPayload() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openFile" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("invalid json")
        }
    }

    @Test("saveFile에 잘못된 JSON을 전달하면 에러가 발생한다")
    func saveFileInvalidPayload() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "saveFile" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("invalid json")
        }
    }

    @Test("showAlert에 잘못된 JSON을 전달하면 에러가 발생한다")
    func showAlertInvalidPayload() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "showAlert" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("invalid json")
        }
    }

    @Test("showAlert에 필수 필드 title이 없으면 에러가 발생한다")
    func showAlertMissingTitle() async throws {
        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "showAlert" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("{\"message\":\"hello\"}")
        }
    }

    @Test("initialize가 에러 없이 완료된다")
    func initializeSucceeds() async throws {
        let context = MockPluginContext(
            container: ContainerActor(),
            eventBus: EventBusActor(),
            logger: StubLogger()
        )
        try await plugin.initialize(context: context)
    }

    @Test("dispose가 에러 없이 완료된다")
    func disposeSucceeds() async {
        await plugin.dispose()
    }

    // MARK: - 실행 테스트

    @Test("showAlert에 유효한 JSON을 전달하면 올바른 응답을 반환한다")
    func showAlertValid() async throws {
        let stubDialogs = StubSystemDialogs(alertResponse: .ok)
        let (plugin, _) = try await Self.makeInitializedPlugin(dialogs: stubDialogs)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "showAlert" })

        let payload = """
        {"title":"경고","message":"계속하시겠습니까?","style":"warning"}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        #expect(decoded["response"] == "ok")
    }

    @Test("showAlert에 cancel 응답이 설정되면 cancel을 반환한다")
    func showAlertCancel() async throws {
        let stubDialogs = StubSystemDialogs(alertResponse: .cancel)
        let (plugin, _) = try await Self.makeInitializedPlugin(dialogs: stubDialogs)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "showAlert" })

        let payload = """
        {"title":"확인","style":"critical"}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        #expect(decoded["response"] == "cancel")
    }

    @Test("openFile에 유효한 JSON을 전달하면 올바른 경로 목록을 반환한다")
    func openFileValid() async throws {
        let stubDialogs = StubSystemDialogs(openPanelPaths: ["/tmp/a.txt", "/tmp/b.txt"])
        let (plugin, _) = try await Self.makeInitializedPlugin(dialogs: stubDialogs)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "openFile" })

        let payload = """
        {"title":"파일 열기","allowedTypes":["txt"],"multiple":true}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode([String: [String]].self, from: data)
        #expect(decoded["paths"] == ["/tmp/a.txt", "/tmp/b.txt"])
    }

    @Test("saveFile에 유효한 JSON을 전달하면 올바른 경로를 반환한다")
    func saveFileValid() async throws {
        let stubDialogs = StubSystemDialogs(savePanelPath: "/tmp/saved.txt")
        let (plugin, _) = try await Self.makeInitializedPlugin(dialogs: stubDialogs)

        let methods = await plugin.methods()
        let method = try #require(methods.first { $0.name == "saveFile" })

        let payload = """
        {"title":"저장","defaultName":"document.txt"}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        #expect(decoded["path"] == "/tmp/saved.txt")
    }

    // MARK: - Helper

    private static func makeInitializedPlugin(
        dialogs: StubSystemDialogs
    ) async throws -> (DialogPlugin, StubContainer) {
        let container = StubContainer()
        let dialogsRef: any SystemDialogs = dialogs
        await container.register((any SystemDialogs).self, scope: .singleton) { dialogsRef }
        let context = MockPluginContext(
            container: container,
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        let plugin = DialogPlugin()
        try await plugin.initialize(context: context)
        return (plugin, container)
    }
}
