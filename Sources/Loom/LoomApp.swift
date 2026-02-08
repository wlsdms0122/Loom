import Foundation
import Core
import Bridge
import Platform
import Plugin
import WebEngine

#if os(macOS)
import PlatformMacOS
#endif

/// Loom 프레임워크의 메인 통합 지점. 모든 모듈을 조합하여 애플리케이션을 실행한다.
// 안전성: @unchecked Sendable — 모든 가변 런타임 상태(`_runtimeState`)는 `_lock`으로 보호된다.
// 불변 프로퍼티는 init에서 설정되며 이후 변경되지 않는다.
public final class LoomApp: Application, @unchecked Sendable {
    // MARK: - Property

    public let id: String
    public let configuration: AppConfiguration
    public var container: any Container { _container }

    private let logger: any Logger
    private let pluginRegistry: PluginRegistryActor
    private let _container: ContainerActor
    private let eventBus: EventBusActor
    private let additionalPlugins: [any Plugin]
    private let additionalWindowConfigs: [WindowConfiguration]
    private let menuItems: [MenuItem]

    /// Lock으로 보호되는 런타임 상태. run() 중에 설정되고 terminate() 중에 정리된다.
    private let _lock = NSLock()
    private var _runtimeState = RuntimeState()

    /// run() 이후에 설정되는 가변 런타임 상태를 캡슐화한다.
    private struct RuntimeState {
        var bridge: BridgeActor?
        var fileWatcher: (any FileWatcher)?
        var webEngine: (any WebEngine)?
        var windowManager: (any WindowManager)?
        var windowHandle: WindowHandle?
        var isRunning: Bool = false
        /// macOS 메뉴 빌더 참조 유지. 해제되면 메뉴 target이 nil이 되어 비활성화된다.
        var menuBuilder: AnyObject?
    }

    // MARK: - Initializer

    public init(
        configuration: AppConfiguration,
        logger: (any Logger)? = nil,
        plugins: [any Plugin] = [],
        additionalWindows: [WindowConfiguration] = [],
        menus: [MenuItem] = []
    ) {
        self.id = configuration.name
        self.configuration = configuration
        self.logger = logger ?? PrintLogger(minLevel: configuration.logLevel)
        self.pluginRegistry = PluginRegistryActor()
        self._container = ContainerActor()
        self.eventBus = EventBusActor()
        self.additionalPlugins = plugins
        self.additionalWindowConfigs = additionalWindows
        self.menuItems = menus
    }

    // MARK: - Public

    /// 애플리케이션을 실행한다.
    @MainActor
    public func run() async throws {
        // 1. 플랫폼 제공자를 생성한다.
        let platform = makePlatformProvider()
        let logger = self.logger

        // 2-3. 윈도우와 웹 뷰를 생성하고 연결한다.
        let (windowManager, windowHandle, nativeWebView) = await setupWindowAndWebView(platform: platform)

        // 4. WebEngine을 설정한다.
        let webEngine = DefaultWebEngine(webView: nativeWebView)

        // 5-6. Bridge를 생성하고 메시지 핸들러를 등록한다.
        let bridge = await setupBridge(webEngine: webEngine, nativeWebView: nativeWebView, logger: logger)

        // 7. 핵심 서비스를 컨테이너에 등록한다.
        await registerServices(platform: platform, logger: logger, windowManager: windowManager)

        // 8-9. 플러그인을 등록하고 Bridge에 연결한다.
        try await setupPlugins(bridge: bridge, logger: logger, windowHandle: windowHandle)

        // 10-13. SDK 주입, 설정 검증, 콘텐츠 로드, 파일 감시를 수행한다.
        try await loadContent(
            webEngine: webEngine,
            platform: platform,
            logger: logger,
            windowManager: windowManager
        )

        // 14. 런타임 상태를 저장한다.
        _lock.withLock {
            _runtimeState.bridge = bridge
            _runtimeState.webEngine = webEngine
            _runtimeState.windowManager = windowManager
            _runtimeState.windowHandle = windowHandle
            _runtimeState.isRunning = true
        }

        // 15. 윈도우를 표시한다.
        await windowManager.showWindow(windowHandle)
    }

    /// 새 윈도우를 생성한다.
    /// - Parameters:
    ///   - id: 윈도우 식별자.
    ///   - configuration: 윈도우 설정.
    @MainActor
    public func createWindow(id: String, configuration: WindowConfiguration) async throws {
        let windowManager: (any WindowManager)? = _lock.withLock {
            _runtimeState.windowManager
        }
        guard let windowManager else {
            throw LoomAppError.notRunning
        }
        let handle = await windowManager.createWindow(id: id, configuration: configuration)
        await windowManager.showWindow(handle)
    }

    /// 애플리케이션을 종료한다. 플러그인 정리, 파일 감시 중지, WebEngine 정리, 윈도우 닫기를 수행한다.
    public func terminate() async {
        // 런타임 상태를 가져오고 초기화한다.
        let state: RuntimeState = _lock.withLock {
            let current = _runtimeState
            _runtimeState = RuntimeState()
            return current
        }

        // 이미 종료된 경우 안전하게 무시한다.
        guard state.isRunning else { return }

        // 1. 각 플러그인의 Bridge 핸들러를 해제하고, 이벤트 핸들러를 정리한다.
        if let bridge = state.bridge {
            let allPlugins = await pluginRegistry.allPlugins()
            for plugin in allPlugins {
                await PluginBridgeConnector.disconnect(plugin: plugin, from: bridge)
            }
            await bridge.removeAllEventHandlers()
        }

        // 2. 플러그인을 정리한다.
        await pluginRegistry.disposeAll()

        // 3. FileWatcher를 중지한다.
        state.fileWatcher?.stop()

        // 4. WebEngine을 정리한다.
        await state.webEngine?.cleanup()

        // 5. 윈도우를 닫는다.
        if let windowHandle = state.windowHandle {
            await state.windowManager?.closeWindow(windowHandle)
        }
    }

    // MARK: - Internal

    /// 테스트에서 런타임 상태를 직접 설정하기 위한 메서드. @testable import에서만 접근 가능하다.
    func setRuntimeState(
        webEngine: (any WebEngine)?,
        windowManager: (any WindowManager)?,
        windowHandle: WindowHandle?,
        fileWatcher: (any FileWatcher)?
    ) {
        _lock.withLock {
            _runtimeState.webEngine = webEngine
            _runtimeState.windowManager = windowManager
            _runtimeState.windowHandle = windowHandle
            _runtimeState.fileWatcher = fileWatcher
            _runtimeState.isRunning = true
        }
    }

    /// 테스트에서 플러그인을 등록하기 위한 메서드. @testable import에서만 접근 가능하다.
    func registerPlugin(_ plugin: any Plugin) async {
        await pluginRegistry.register(plugin)
    }

    /// 테스트에서 플러그인을 초기화하기 위한 메서드. @testable import에서만 접근 가능하다.
    func initializePlugins(context: any PluginContext) async throws {
        try await pluginRegistry.initializeAll(context: context)
    }

    // MARK: - Private

    /// 현재 플랫폼에 맞는 PlatformProvider를 생성한다.
    @MainActor
    private func makePlatformProvider() -> any PlatformProvider {
        #if os(macOS)
        return MacOSPlatformProvider()
        #else
        fatalError("지원되지 않는 플랫폼")
        #endif
    }

    /// 윈도우와 웹 뷰를 생성하고 연결한다. (Steps 2-3)
    @MainActor
    private func setupWindowAndWebView(
        platform: any PlatformProvider
    ) async -> (any WindowManager, WindowHandle, any NativeWebView) {
        // 2. 윈도우와 웹 뷰를 생성한다.
        let windowManager: any WindowManager
        do {
            var wm = platform.makeWindowManager()
            // 2-1. 마지막 윈도우 닫기 시 앱 종료 옵션을 설정한다.
            wm.terminateOnLastWindowClose = configuration.terminateOnLastWindowClose
            windowManager = wm
        }

        let windowHandle = await windowManager.createWindow(
            configuration: configuration.window
        )
        // 2-2. 진입점 유형에 따라 웹 뷰를 생성한다. 플랫폼 제공자가 스킴 핸들러를 내부적으로 설정한다.
        let nativeWebView = platform.makeWebView(
            configuration: configuration.window,
            entry: configuration.resolvedEntry
        )

        // 3. 웹 뷰를 윈도우에 연결한다.
        await windowManager.attachWebView(nativeWebView, to: windowHandle)

        return (windowManager, windowHandle, nativeWebView)
    }

    /// Bridge를 생성하고 메시지 핸들러를 등록한다. (Steps 5-6)
    @MainActor
    private func setupBridge(
        webEngine: DefaultWebEngine,
        nativeWebView: any NativeWebView,
        logger: any Logger
    ) async -> BridgeActor {
        // 5. Bridge를 생성한다.
        let bridge = BridgeActor(
            transport: WebEngineBridgeTransport(engine: webEngine),
            logger: logger
        )

        // 6. Bridge 메시지 핸들러를 등록한다.
        await webEngine.addMessageHandler(name: "loom") { [bridge] body in
            guard let bodyString = body as? String else { return }
            await bridge.receive(bodyString)
        }

        // 6-1. DEBUG 빌드에서 JS console 메시지를 Swift Logger로 포워딩한다.
        nativeWebView.enableConsoleForwarding(logger: logger)

        return bridge
    }

    /// 핵심 서비스를 DI 컨테이너에 등록한다. (Step 7)
    @MainActor
    private func registerServices(
        platform: any PlatformProvider,
        logger: any Logger,
        windowManager: any WindowManager
    ) async {
        // 7. 핵심 서비스를 컨테이너에 등록한다.
        await _container.register((any Logger).self, scope: .singleton) { logger }
        await _container.register((any EventBus).self, scope: .singleton) { [eventBus] in eventBus }

        // 7-1. 플랫폼 서비스를 컨테이너에 등록한다.
        let fileSystem = platform.makeFileSystem()
        let dialogs = platform.makeDialogs()
        await _container.register((any FileSystem).self, scope: .singleton) { fileSystem }
        await _container.register((any SystemDialogs).self, scope: .singleton) { dialogs }
        let clipboard = platform.makeClipboard()
        let shell = platform.makeShell()
        await _container.register((any Clipboard).self, scope: .singleton) { clipboard }
        await _container.register((any Shell).self, scope: .singleton) { shell }

        // 7-2. URL 스킴 화이트리스트를 컨테이너에 등록한다.
        let urlSchemeWhitelist = URLSchemeWhitelist(schemes: configuration.allowedURLSchemes)
        await _container.register(URLSchemeWhitelist.self, scope: .singleton) { urlSchemeWhitelist }

        // 7-3. WindowManager를 컨테이너에 등록한다.
        await _container.register((any WindowManager).self, scope: .singleton) { windowManager }
    }

    /// 플러그인을 등록하고 초기화하며 Bridge에 연결한다. (Steps 8-9)
    @MainActor
    private func setupPlugins(
        bridge: BridgeActor,
        logger: any Logger,
        windowHandle: WindowHandle
    ) async throws {
        // 8. 플러그인을 등록하고 초기화한다.
        let windowPlugin = WindowPlugin(windowHandle: windowHandle)
        await pluginRegistry.register(windowPlugin)

        for plugin in additionalPlugins {
            await pluginRegistry.register(plugin)
        }

        let context = LoomPluginContext(
            container: _container,
            eventBus: eventBus,
            logger: logger,
            bridge: bridge
        )
        try await pluginRegistry.initializeAll(context: context)

        // 9. 플러그인 메서드를 Bridge에 연결한다.
        let allPlugins = await pluginRegistry.allPlugins()
        await PluginBridgeConnector.connect(
            plugins: allPlugins,
            to: bridge
        )
    }

    /// SDK 주입, 설정 검증, 메뉴 빌드, 콘텐츠 로드, 파일 감시를 수행한다. (Steps 10-13)
    @MainActor
    private func loadContent(
        webEngine: DefaultWebEngine,
        platform: any PlatformProvider,
        logger: any Logger,
        windowManager: any WindowManager
    ) async throws {
        // 10. Bridge SDK를 주입한다.
        let sdkProvider = DefaultBridgeSDKProvider()
        let sdk = try sdkProvider.generateSDK()
        await webEngine.injectBridgeSDK(sdk)

        // 11. 설정을 검증하고 경고를 출력한다.
        let warnings = configuration.validate()
        for warning in warnings {
            logger.warning("[Loom] \(warning)")
        }

        // 11-1. 메뉴가 설정된 경우 앱 메뉴바를 빌드한다.
        if !menuItems.isEmpty {
            let menuBuilder = platform.applyMenu(menuItems)
            // menuBuilder를 유지하여 MenuItemTarget이 해제되지 않도록 한다.
            _lock.withLock {
                _runtimeState.menuBuilder = menuBuilder
            }
        }

        // 11-2. 추가 윈도우를 생성한다.
        for (index, windowConfig) in additionalWindowConfigs.enumerated() {
            let windowId = "additional-\(index)"
            let handle = await windowManager.createWindow(id: windowId, configuration: windowConfig)
            await windowManager.showWindow(handle)
        }

        // 12. 웹 콘텐츠를 로드한다.
        let entryURL = try configuration.resolvedEntry.resolveLoadURL()
        await webEngine.load(url: entryURL)

        #if DEBUG
        logger.debug("[Loom] 진입점: \(entryURL)")
        logger.debug("[Loom] 파일 감시: \(configuration.shouldWatchFiles)")
        #endif

        // 13. 필요 시 파일 변경을 감시한다.
        if configuration.shouldWatchFiles, case .file(let fileURL) = configuration.resolvedEntry {
            let watcher = platform.makeFileWatcher()
            startFileWatcher(watcher: watcher, path: fileURL.filePath, webEngine: webEngine, logger: logger)
        }
    }

    /// 파일 변경 감시를 시작한다. platformProvider가 제공한 FileWatcher를 사용한다.
    private func startFileWatcher(
        watcher: (any FileWatcher)?,
        path: String,
        webEngine: DefaultWebEngine,
        logger: any Logger
    ) {
        guard let watcher else { return }

        let directory = URL(fileURLWithPath: path).deletingLastPathComponent().filePath
        _lock.withLock {
            _runtimeState.fileWatcher = watcher
        }
        do {
            try watcher.start(watching: directory) { [weak webEngine] in
                guard let webEngine else { return }
                Task { @MainActor in
                    webEngine.reload()
                }
            }
        } catch {
            logger.warning("FileWatcher 시작 실패: \(error.localizedDescription)")
        }
    }
}
