public struct AppConfiguration: Sendable {
    // MARK: - Property
    public let name: String
    public let entry: EntryPoint
    public let window: WindowConfiguration
    public let isDebug: Bool
    public let debugEntry: EntryPoint?
    public let allowedURLSchemes: [String]
    public let logLevel: LogLevel

    /// 마지막 윈도우가 닫힐 때 앱을 종료할지 여부. 기본값은 true.
    public let terminateOnLastWindowClose: Bool

    // MARK: - Initializer
    public init(
        name: String,
        entry: EntryPoint,
        window: WindowConfiguration = WindowConfiguration(),
        debugEntry: EntryPoint? = nil,
        allowedURLSchemes: [String] = ["http", "https"],
        logLevel: LogLevel = .debug,
        terminateOnLastWindowClose: Bool = true
    ) {
        self.name = name
        self.entry = entry
        self.window = window
        self.debugEntry = debugEntry
        self.allowedURLSchemes = allowedURLSchemes
        self.logLevel = logLevel
        self.terminateOnLastWindowClose = terminateOnLastWindowClose
        #if DEBUG
        self.isDebug = true
        #else
        self.isDebug = false
        #endif
    }

    // MARK: - Internal
    init(
        name: String,
        entry: EntryPoint,
        window: WindowConfiguration = WindowConfiguration(),
        debugEntry: EntryPoint? = nil,
        allowedURLSchemes: [String] = ["http", "https"],
        logLevel: LogLevel = .debug,
        terminateOnLastWindowClose: Bool = true,
        isDebug: Bool
    ) {
        self.name = name
        self.entry = entry
        self.window = window
        self.debugEntry = debugEntry
        self.allowedURLSchemes = allowedURLSchemes
        self.logLevel = logLevel
        self.terminateOnLastWindowClose = terminateOnLastWindowClose
        self.isDebug = isDebug
    }

    // MARK: - Public
    public var resolvedEntry: EntryPoint {
        isDebug ? (debugEntry ?? entry) : entry
    }

    public var shouldWatchFiles: Bool {
        guard isDebug else { return false }
        if case .file = resolvedEntry { return true }
        return false
    }

    public func validate() -> [String] {
        var warnings: [String] = []
        if entry.isLocalhost {
            warnings.append("entry가 localhost 개발 서버를 가리키고 있습니다.")
        }
        return warnings
    }
}
