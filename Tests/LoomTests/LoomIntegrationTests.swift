import Testing
import Foundation
@testable import Core
import Bridge
import Platform
import Plugin
import WebEngine
@testable import Loom
import LoomTestKit

/// LoomApp의 핵심 흐름을 통합 검증한다.
/// 윈도우 생성 -> WebView 연결 -> 플러그인 등록 -> SDK 주입 -> 콘텐츠 로드 -> JS<->Swift 통신.
@Suite("Loom 통합 테스트")
struct LoomIntegrationTests {
    // MARK: - Property

    private let webView: MockNativeWebView
    private let windowManager: MockWindowManager

    // MARK: - Initializer

    init() {
        webView = MockNativeWebView()
        windowManager = MockWindowManager()
    }

    // MARK: - Tests

    @Test("전체 초기화 흐름에서 WebView가 윈도우에 연결된다")
    func attachWebViewDuringSetup() async throws {
        let handle = await windowManager.createWindow(
            configuration: WindowConfiguration(title: "Test")
        )

        await windowManager.attachWebView(webView, to: handle)

        #expect(windowManager.attachedCount == 1)
    }

    @Test("Bridge SDK가 WebEngine을 통해 WebView에 주입된다")
    func bridgeSDKInjection() async throws {
        let engine = DefaultWebEngine(webView: webView)
        let sdkProvider = DefaultBridgeSDKProvider()
        let sdk = try sdkProvider.generateSDK()

        await engine.injectBridgeSDK(sdk)

        #expect(webView.userScripts.count == 1)
        #expect(webView.userScripts.first?.injectionTime == .atDocumentStart)
        #expect(webView.userScripts.first?.script.contains("window.loom") == true)
    }

    @Test("플러그인 등록 후 Bridge를 통해 메서드가 호출 가능하다")
    func pluginMethodRegistration() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let plugin = MockTestPlugin(name: "greeter", methods: [
            PluginMethod(name: "hello") { payload in
                struct Args: Codable { let name: String }
                struct Result: Codable { let message: String }
                let args = try JSONDecoder().decode(Args.self, from: Data(payload.utf8))
                return String(
                    data: try JSONEncoder().encode(Result(message: "Hello, \(args.name)!")),
                    encoding: .utf8
                ) ?? "{}"
            }
        ])

        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)

        // JS에서 보내는 것과 동일한 request 메시지를 시뮬레이션한다.
        let payload = "{\"name\":\"Loom\"}"
        let request = BridgeMessage(
            id: "test_1",
            method: "plugin.greeter.hello",
            payload: payload,
            kind: .request
        )
        let requestJSON = try JSONEncoder().encode(request)
        let requestString = String(data: requestJSON, encoding: .utf8)!
        await bridge.receive(requestString)

        // Bridge가 transport를 통해 응답을 전송했는지 확인한다.
        let sentData = transport.sentData
        #expect(!sentData.isEmpty)

        let responseData = try #require(sentData.first)
        let response = try JSONDecoder().decode(BridgeMessage.self, from: responseData)
        #expect(response.id == "test_1")
        #expect(response.kind == .response)

        let resultJSON = try #require(response.payload)
        #expect(resultJSON.contains("Hello, Loom!"))
    }

    @Test("로컬 경로로 WebEngine이 콘텐츠를 로드한다")
    func loadLocalContent() async {
        let engine = DefaultWebEngine(webView: webView)
        let url = URL(fileURLWithPath: "/tmp/test/index.html")

        await engine.load(url: url)

        #expect(webView.loadedURLs.count == 1)
        #expect(webView.loadedURLs.first?.path.contains("index.html") == true)
    }

    @Test("원격 URL로 WebEngine이 콘텐츠를 로드한다")
    func loadRemoteContent() async {
        let engine = DefaultWebEngine(webView: webView)
        let url = URL(string: "https://localhost:3000")!

        await engine.load(url: url)

        #expect(webView.loadedURLs.count == 1)
        #expect(webView.loadedURLs.first == url)
    }

    @Test("메시지 핸들러 등록 후 WebView에서 메시지를 수신할 수 있다")
    func messageHandlerReceivesMessages() async throws {
        let engine = DefaultWebEngine(webView: webView)
        let box = MessageBox()

        await engine.addMessageHandler(name: "loom") { body in
            if let str = body as? String {
                await box.set(str)
            }
        }

        // WebView에서 JS가 메시지를 보내는 것을 시뮬레이션한다.
        await webView.simulateMessage(name: "loom", body: "test_message")

        let received = await box.value
        #expect(received == "test_message")
    }

    @Test("JS -> Swift -> JS 왕복 통신이 완료된다")
    func fullRoundTrip() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)
        let engine = DefaultWebEngine(webView: webView)

        // 1. 메시지 핸들러를 등록한다 (LoomApp.run() step 6과 동일).
        await engine.addMessageHandler(name: "loom") { body in
            guard let bodyString = body as? String else { return }
            await bridge.receive(bodyString)
        }

        // 2. echo 플러그인을 등록한다.
        let plugin = MockTestPlugin(name: "echo", methods: [
            PluginMethod(name: "ping") { payload in
                payload
            }
        ])
        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)

        // 3. JS에서 보내는 JSON 메시지를 시뮬레이션한다.
        let requestPayload = "pong"
        let request = BridgeMessage(
            id: "round_trip_1",
            method: "plugin.echo.ping",
            payload: requestPayload,
            kind: .request
        )
        let requestJSON = try JSONEncoder().encode(request)
        let requestString = String(data: requestJSON, encoding: .utf8)!

        await webView.simulateMessage(name: "loom", body: requestString)

        // 4. 비동기 처리 대기: transport에 데이터가 도착할 때까지 폴링한다.
        for _ in 0..<100 {
            if !transport.sentData.isEmpty { break }
            await Task.yield()
        }

        // 5. Bridge가 응답을 transport로 전송했는지 확인한다.
        let sentData = transport.sentData
        #expect(!sentData.isEmpty)

        let responseData = try #require(sentData.first)
        let response = try JSONDecoder().decode(BridgeMessage.self, from: responseData)
        #expect(response.id == "round_trip_1")
        #expect(response.kind == .response)

        let resultJSON = try #require(response.payload)
        #expect(resultJSON == "pong")
    }

    @Test("여러 플러그인이 동시에 등록되고 각각 호출 가능하다")
    func multiplePluginsRegistration() async throws {
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport)

        let fsPlugin = MockTestPlugin(name: "filesystem", methods: [
            PluginMethod(name: "exists") { _ in "{\"exists\":true}" }
        ])
        let clipPlugin = MockTestPlugin(name: "clipboard", methods: [
            PluginMethod(name: "readText") { _ in "{\"text\":\"hello\"}" }
        ])

        await PluginBridgeConnector.connect(plugins: [fsPlugin, clipPlugin], to: bridge)

        // filesystem.exists 호출
        let fsRequest = BridgeMessage(
            id: "multi_1",
            method: "plugin.filesystem.exists",
            payload: "{}",
            kind: .request
        )
        let fsRequestJSON = try JSONEncoder().encode(fsRequest)
        let fsRequestString = String(data: fsRequestJSON, encoding: .utf8)!
        await bridge.receive(fsRequestString)

        // clipboard.readText 호출
        let clipRequest = BridgeMessage(
            id: "multi_2",
            method: "plugin.clipboard.readText",
            payload: "{}",
            kind: .request
        )
        let clipRequestJSON = try JSONEncoder().encode(clipRequest)
        let clipRequestString = String(data: clipRequestJSON, encoding: .utf8)!
        await bridge.receive(clipRequestString)

        let sentData = transport.sentData
        #expect(sentData.count == 2)

        let fsResponse = try JSONDecoder().decode(BridgeMessage.self, from: sentData[0])
        #expect(fsResponse.id == "multi_1")
        #expect(fsResponse.kind == .response)
        let fsResult = try #require(fsResponse.payload)
        #expect(fsResult.contains("exists"))

        let clipResponse = try JSONDecoder().decode(BridgeMessage.self, from: sentData[1])
        #expect(clipResponse.id == "multi_2")
        #expect(clipResponse.kind == .response)
        let clipResult = try #require(clipResponse.payload)
        #expect(clipResult.contains("hello"))
    }

    @Test("디버그 모드에서 debugEntry가 있으면 해당 경로로 로드한다")
    func loadDebugEntryInDebugMode() async throws {
        let engine = DefaultWebEngine(webView: webView)

        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/bundle/index.html")),
            debugEntry: .file(URL(fileURLWithPath: "/src/index.html")),
            isDebug: true
        )

        let effectiveEntry = config.resolvedEntry
        await engine.load(url: try effectiveEntry.resolveURL())

        #expect(webView.loadedURLs.count == 1)
        #expect(webView.loadedURLs.first?.path.contains("/src/index.html") == true)
    }

    @Test("릴리스 모드에서는 debugEntry가 있어도 entry를 사용한다")
    func loadEntryInReleaseMode() async throws {
        let engine = DefaultWebEngine(webView: webView)

        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/bundle/index.html")),
            debugEntry: .file(URL(fileURLWithPath: "/src/index.html")),
            isDebug: false
        )

        let effectiveEntry = config.resolvedEntry
        await engine.load(url: try effectiveEntry.resolveURL())

        #expect(webView.loadedURLs.count == 1)
        #expect(webView.loadedURLs.first?.path.contains("/bundle/index.html") == true)
    }

    @Test("릴리스 모드에서 debugEntry로 원격 URL이 있어도 entry를 사용한다")
    func loadEntryIgnoresRemoteDebugEntry() async throws {
        let engine = DefaultWebEngine(webView: webView)

        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/bundle/index.html")),
            debugEntry: .remote(URL(string: "http://localhost:5173")!),
            isDebug: false
        )

        let effectiveEntry = config.resolvedEntry
        await engine.load(url: try effectiveEntry.resolveURL())

        #expect(webView.loadedURLs.count == 1)
        #expect(webView.loadedURLs.first?.path.contains("/bundle/index.html") == true)
    }

    @Test("validate()가 localhost entry에 대해 경고를 반환한다")
    func validateReturnsWarningsForLocalhostEntry() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .remote(URL(string: "http://localhost:3000")!),
            isDebug: false
        )

        let warnings = config.validate()
        #expect(!warnings.isEmpty)
        #expect(warnings.contains { $0.contains("localhost") })
    }

    @Test("validate()가 안전한 설정에 대해 빈 배열을 반환한다")
    func validateReturnsEmptyForSafeConfig() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/bundle/index.html")),
            isDebug: false
        )

        #expect(config.validate().isEmpty)
    }

    @Test("윈도우 생성 -> WebView 연결 -> 콘텐츠 로드 -> 윈도우 표시 순서가 올바르다")
    func setupFlowOrder() async {
        let engine = DefaultWebEngine(webView: webView)
        let config = WindowConfiguration(
            width: 1000,
            height: 700,
            title: "Test Window",
            resizable: true
        )

        // 1. 윈도우 생성
        let handle = await windowManager.createWindow(configuration: config)
        #expect(windowManager.createdConfigurations.count == 1)

        // 2. WebView 연결
        await windowManager.attachWebView(webView, to: handle)
        #expect(windowManager.attachedCount == 1)

        // 3. 콘텐츠 로드
        let url = URL(fileURLWithPath: "/test/index.html")
        await engine.load(url: url)
        #expect(webView.loadedURLs.count == 1)

        // 4. 윈도우 표시
        await windowManager.showWindow(handle)
        #expect(windowManager.shownHandles.count == 1)
    }
}

// MARK: - Terminate Tests

/// LoomApp.terminate()의 종료 흐름을 검증한다.
@Suite("LoomApp 종료 테스트")
struct LoomAppTerminateTests {
    // MARK: - Property

    private let configuration: AppConfiguration

    // MARK: - Initializer

    init() {
        configuration = AppConfiguration(
            name: "TerminateTestApp",
            entry: .file(URL(fileURLWithPath: "/tmp/index.html")),
            isDebug: false
        )
    }

    // MARK: - Tests

    @Test("terminate() 호출 시 모든 플러그인의 dispose()가 호출된다")
    func terminateDisposesAllPlugins() async throws {
        let pluginA = MockPlugin(name: "pluginA")
        let pluginB = MockPlugin(name: "pluginB")
        let pluginC = MockPlugin(name: "pluginC")

        let app = LoomApp(configuration: configuration, plugins: [pluginA, pluginB, pluginC])

        // 플러그인을 등록하고 초기화한다.
        let context = MockPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        for plugin in [pluginA, pluginB, pluginC] {
            await app.registerPlugin(plugin)
        }
        try await app.initializePlugins(context: context)

        // 런타임 상태를 설정하여 앱이 실행 중인 것처럼 만든다.
        let webView = MockNativeWebView()
        let engine = DefaultWebEngine(webView: webView)
        let windowManager = MockWindowManager()
        let handle = await windowManager.createWindow(
            configuration: WindowConfiguration(title: "Test")
        )
        app.setRuntimeState(
            webEngine: engine,
            windowManager: windowManager,
            windowHandle: handle,
            fileWatcher: nil
        )

        // terminate()를 호출한다.
        await app.terminate()

        // 모든 플러그인의 dispose()가 호출되었는지 확인한다.
        #expect(pluginA.disposeCalled)
        #expect(pluginB.disposeCalled)
        #expect(pluginC.disposeCalled)
    }

    @Test("terminate() 호출 시 FileWatcher가 중지된다")
    func terminateStopsFileWatcher() async {
        let app = LoomApp(configuration: configuration)

        // MockFileWatcher를 생성하고 런타임 상태에 설정한다.
        let fileWatcher = MockFileWatcher()
        let webView = MockNativeWebView()
        let engine = DefaultWebEngine(webView: webView)
        let windowManager = MockWindowManager()
        let handle = await windowManager.createWindow(
            configuration: WindowConfiguration(title: "Test")
        )

        app.setRuntimeState(
            webEngine: engine,
            windowManager: windowManager,
            windowHandle: handle,
            fileWatcher: fileWatcher
        )

        #expect(fileWatcher.stopCount == 0)

        // terminate()를 호출한다.
        await app.terminate()

        // FileWatcher.stop()이 호출되었는지 확인한다.
        #expect(fileWatcher.stopCount == 1)
    }

    @Test("terminate()를 여러 번 호출해도 안전하다")
    func terminateCanBeCalledMultipleTimes() async {
        let plugin = MockPlugin(name: "safePlugin")
        let app = LoomApp(configuration: configuration, plugins: [plugin])

        let context = MockPluginContext(
            container: StubContainer(),
            eventBus: StubEventBus(),
            logger: StubLogger()
        )
        await app.registerPlugin(plugin)
        try? await app.initializePlugins(context: context)

        let fileWatcher = MockFileWatcher()
        let webView = MockNativeWebView()
        let engine = DefaultWebEngine(webView: webView)
        let windowManager = MockWindowManager()
        let handle = await windowManager.createWindow(
            configuration: WindowConfiguration(title: "Test")
        )

        app.setRuntimeState(
            webEngine: engine,
            windowManager: windowManager,
            windowHandle: handle,
            fileWatcher: fileWatcher
        )

        // terminate()를 세 번 호출한다.
        await app.terminate()
        await app.terminate()
        await app.terminate()

        // FileWatcher.stop()은 한 번만 호출되어야 한다.
        #expect(fileWatcher.stopCount == 1)

        // WebEngine.cleanup()은 한 번만 호출되어야 한다.
        #expect(webView.cleanupCount == 1)

        // 윈도우 닫기도 한 번만 호출되어야 한다.
        #expect(windowManager.closedHandles.count == 1)
    }

    @Test("terminate() 호출 시 WebEngine.cleanup()이 호출된다")
    func terminateCleansUpWebEngine() async {
        let app = LoomApp(configuration: configuration)

        let webView = MockNativeWebView()
        let engine = DefaultWebEngine(webView: webView)
        let windowManager = MockWindowManager()
        let handle = await windowManager.createWindow(
            configuration: WindowConfiguration(title: "Test")
        )

        app.setRuntimeState(
            webEngine: engine,
            windowManager: windowManager,
            windowHandle: handle,
            fileWatcher: nil
        )

        #expect(webView.cleanupCount == 0)

        await app.terminate()

        #expect(webView.cleanupCount == 1)
    }

    @Test("terminate() 호출 시 윈도우가 닫힌다")
    func terminateClosesWindow() async {
        let app = LoomApp(configuration: configuration)

        let webView = MockNativeWebView()
        let engine = DefaultWebEngine(webView: webView)
        let windowManager = MockWindowManager()
        let handle = await windowManager.createWindow(
            configuration: WindowConfiguration(title: "Test")
        )

        app.setRuntimeState(
            webEngine: engine,
            windowManager: windowManager,
            windowHandle: handle,
            fileWatcher: nil
        )

        #expect(windowManager.closedHandles.isEmpty)

        await app.terminate()

        #expect(windowManager.closedHandles.count == 1)
        #expect(windowManager.closedHandles.first == handle)
    }

    @Test("run() 전에 terminate()를 호출해도 안전하다")
    func terminateBeforeRunIsSafe() async {
        let app = LoomApp(configuration: configuration)

        // run() 없이 terminate()를 호출해도 크래시가 발생하지 않아야 한다.
        await app.terminate()
    }
}

// MARK: - Bridge 메시지 파싱 로깅 테스트

/// BridgeActor가 잘못된 메시지를 수신했을 때 로거에 에러가 기록되는지 검증한다.
@Suite("Bridge 메시지 파싱 로깅")
struct BridgeMessageParsingLoggingTests {
    // MARK: - Property

    private let webView: MockNativeWebView

    // MARK: - Initializer

    init() {
        webView = MockNativeWebView()
    }

    // MARK: - Tests

    @Test("body가 String이 아닌 경우 메시지가 무시된다")
    func nonStringBodyIsIgnored() async {
        let logger = SpyLogger()
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport, logger: logger)
        let engine = DefaultWebEngine(webView: webView)

        await engine.addMessageHandler(name: "loom") { [bridge] body in
            guard let bodyString = body as? String else { return }
            await bridge.receive(bodyString)
        }

        // String이 아닌 Int를 전송한다.
        await webView.simulateMessage(name: "loom", body: 12345)

        // bridge.receive가 호출되지 않으므로 로그도 없어야 한다.
        // (guard let에서 return하므로 bridge에 도달하지 않음)
        let sentData = transport.sentData
        #expect(sentData.isEmpty)
    }

    @Test("유효하지 않은 JSON이 전송되면 디코딩 실패 에러가 로깅된다")
    func logsErrorWhenJSONDecodingFails() async {
        let logger = SpyLogger()
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport, logger: logger)
        let engine = DefaultWebEngine(webView: webView)

        await engine.addMessageHandler(name: "loom") { [bridge] body in
            guard let bodyString = body as? String else { return }
            await bridge.receive(bodyString)
        }

        // 유효하지 않은 JSON 문자열을 전송한다.
        await webView.simulateMessage(name: "loom", body: "not a valid json{{{")

        // BridgeActor 내부에서 디코딩 실패 에러가 로깅되었는지 확인
        let errors = logger.entries.filter { $0.level == .error }
        #expect(errors.count == 1)
        #expect(errors.first?.message.contains("JSON 디코딩 실패") == true)
    }

    @Test("유효한 BridgeMessage가 전송되면 에러가 로깅되지 않는다")
    func noErrorLoggedForValidMessage() async throws {
        let logger = SpyLogger()
        let transport = MockBridgeTransport()
        let bridge = BridgeActor(transport: transport, logger: logger)
        let engine = DefaultWebEngine(webView: webView)

        let plugin = MockTestPlugin(name: "echo", methods: [
            PluginMethod(name: "ping") { payload in payload }
        ])
        await PluginBridgeConnector.connect(plugins: [plugin], to: bridge)

        await engine.addMessageHandler(name: "loom") { [bridge] body in
            guard let bodyString = body as? String else { return }
            await bridge.receive(bodyString)
        }

        // 유효한 BridgeMessage를 전송한다.
        let request = BridgeMessage(
            id: "log_test_1",
            method: "plugin.echo.ping",
            payload: "test",
            kind: .request
        )
        let requestJSON = try JSONEncoder().encode(request)
        let requestString = String(data: requestJSON, encoding: .utf8)!

        await webView.simulateMessage(name: "loom", body: requestString)

        let errors = logger.entries.filter { $0.level == .error }
        #expect(errors.isEmpty)
    }
}

// MARK: - Test Helper

/// 테스트용 Sendable 값 컨테이너.
actor MessageBox {
    private(set) var value: String?

    func set(_ v: String) { value = v }
}

/// 테스트용 모의 Plugin.
final class MockTestPlugin: Plugin, @unchecked Sendable {
    let name: String
    private let _methods: [PluginMethod]

    init(name: String, methods: [PluginMethod]) {
        self.name = name
        self._methods = methods
    }

    func initialize(context: any PluginContext) async throws {}
    func methods() async -> [PluginMethod] { _methods }
    func dispose() async {}
}
