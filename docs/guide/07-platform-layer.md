# 플랫폼 레이어

PlatformProvider 프로토콜, macOS 구현체, 크로스 플랫폼 확장 전략.

---

## PlatformProvider 프로토콜

각 OS별 네이티브 기능을 추상화하는 팩토리 프로토콜이다.

```swift
@MainActor
public protocol PlatformProvider: Sendable {
    func makeWindowManager() -> any WindowManager
    func makeWebView(configuration: WindowConfiguration) -> any NativeWebView
    func makeFileSystem() -> any FileSystem
    func makeDialogs() -> any SystemDialogs
    func makeClipboard() -> any Clipboard
    func makeShell() -> any Shell
    func makeFileWatcher() -> (any FileWatcher)?
    func makeStatusItem() -> (any StatusItem)?
    var system: SystemInfo { get }
}
```

`makeFileWatcher()`와 `makeStatusItem()`은 기본적으로 `nil`을 반환하는 기본 구현이 제공된다.

---

## 주요 Platform 프로토콜

### WindowManager

```swift
public protocol WindowManager: Sendable {
    func createWindow(configuration: WindowConfiguration) async -> WindowHandle
    func createWindow(id: String, configuration: WindowConfiguration) async -> WindowHandle
    func attachWebView(_ webView: any NativeWebView, to handle: WindowHandle) async
    func closeWindow(_ handle: WindowHandle) async
    func showWindow(_ handle: WindowHandle) async
}
```

### NativeWebView

```swift
public protocol NativeWebView: Sendable {
    func loadURL(_ url: URL) async
    func loadHTML(_ html: String) async
    func evaluateJavaScript(_ script: String) async throws -> (any Sendable)?
    func addUserScript(_ script: String, injectionTime: ScriptInjectionTime) async
    func addMessageHandler(name: String, handler: @escaping @Sendable (Any) async -> Void) async
    func cleanup() async
    @MainActor func reload()
}
```

### FileSystem

```swift
public protocol FileSystem: Sendable {
    func exists(at path: String) -> Bool
    func readData(at path: String) throws -> Data
    func writeData(_ data: Data, to path: String) throws
    func delete(at path: String) throws
    func createDirectory(at path: String) throws
    func listContents(at path: String) throws -> [String]
}
```

### FileWatcher

```swift
public protocol FileWatcher: Sendable {
    func start(watching directory: String, onChange: @escaping @Sendable () -> Void) throws
    func stop()
}
```

### SystemDialogs, Clipboard, Shell

각각 대화상자, 클립보드, 셸 유틸리티의 추상화를 제공한다. 자세한 인터페이스는 `Sources/Platform/` 디렉토리에서 확인할 수 있다.

---

## macOS 구현체

`PlatformMacOS` 모듈에서 모든 Platform 프로토콜의 macOS 구현을 제공한다.

| 구현체 | 프로토콜 | 기반 기술 |
|--------|---------|----------|
| `MacOSPlatformProvider` | `PlatformProvider` | AppKit |
| `MacOSWindowManager` | `WindowManager` | NSWindow |
| `MacOSWebView` | `NativeWebView` | WKWebView |
| `MacOSFileSystem` | `FileSystem` | FileManager |
| `MacOSFileWatcher` | `FileWatcher` | DispatchSource |
| `MacOSDialogs` | `SystemDialogs` | NSOpenPanel, NSSavePanel, NSAlert |
| `MacOSClipboard` | `Clipboard` | NSPasteboard |
| `MacOSShell` | `Shell` | NSWorkspace |

### MacOSPlatformProvider

`@MainActor`로 격리되어 모든 팩토리 메서드가 메인 스레드에서 실행된다.

```swift
@MainActor
public final class MacOSPlatformProvider: PlatformProvider, @unchecked Sendable {
    public func makeWindowManager() -> any WindowManager { MacOSWindowManager() }
    public func makeWebView(configuration: WindowConfiguration) -> any NativeWebView {
        MacOSWebView(configuration: configuration)
    }
    public func makeFileSystem() -> any FileSystem { MacOSFileSystem() }
    public func makeDialogs() -> any SystemDialogs { MacOSDialogs() }
    public func makeClipboard() -> any Clipboard { MacOSClipboard() }
    public func makeShell() -> any Shell { MacOSShell() }
    public func makeFileWatcher() -> (any FileWatcher)? { MacOSFileWatcher() }
    // ...
}
```

### MacOSWebView 특이사항

- DEBUG 빌드에서 `webView.isInspectable = true`로 설정되어 Safari Web Inspector를 사용할 수 있다
- `enableConsoleForwarding(logger:)`로 JS console 메시지를 Swift Logger로 포워딩할 수 있다
- 외부 URL 클릭 시 기본 브라우저에서 열리도록 네비게이션 정책이 적용된다

---

## 크로스 플랫폼 확장 전략

현재 macOS만 지원하지만, Platform 모듈의 프로토콜 기반 설계로 향후 다른 플랫폼 지원이 가능하다.

```
Sources/
+-- Platform/              # 프로토콜 정의 (모든 플랫폼 공유)
+-- PlatformMacOS/         # macOS 구현 (WKWebView, AppKit)
+-- PlatformLinux/         # Linux 구현 (향후 - WebKitGTK, GTK)
+-- PlatformWindows/       # Windows 구현 (향후 - WebView2, WinUI)
```

### 조건부 컴파일

SPM의 조건부 의존성으로 플랫폼별 빌드를 관리한다.

```swift
.target(name: "Loom", dependencies: [
    "Core", "Bridge", "Platform", "Plugin", "WebEngine",
    .target(name: "PlatformMacOS", condition: .when(platforms: [.macOS]))
])
```

### 플랫폼 팩토리

`LoomApp` 내부에서 현재 플랫폼의 `PlatformProvider`를 자동 선택한다.

```swift
@MainActor
private func makePlatformProvider() -> any PlatformProvider {
    #if os(macOS)
    return MacOSPlatformProvider()
    #else
    fatalError("지원되지 않는 플랫폼")
    #endif
}
```

---

## 다음 단계

- [보안](08-security.md) - SecurityPolicy와 PathSandbox
- [아키텍처](03-architecture.md) - 전체 모듈 구조
