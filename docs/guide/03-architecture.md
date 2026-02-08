# 아키텍처

Loom의 모듈 구조, 의존성 그래프, 데이터 흐름, 동시성 모델.

---

## 시스템 다이어그램

```
+-----------------------------------------------------------------+
|                      Loom Application                           |
|                                                                 |
|  +-----------------------------------------------------------+ |
|  |                    Web Frontend                            | |
|  |             (React / Svelte / Vue / etc.)                  | |
|  +---------------------------+--------------------------------+ |
|                              | JS API (loom.invoke / loom.on)   |
|  +---------------------------+--------------------------------+ |
|  |                                                            | |
|  |  +-----------+    +-----------+    +------------------+    | |
|  |  | WebEngine |<-->|  Bridge   |<-->|     Plugin       |    | |
|  |  |           |    |           |    |                  |    | |
|  |  | Rendering |    | Message   |    | Registry         |    | |
|  |  | Script    |    | Codec     |    | Lifecycle        |    | |
|  |  | Injection |    | Router    |    | API Expose       |    | |
|  |  +-----+-----+    +-----+-----+    +--------+---------+    | |
|  |        |                 |                   |             | |
|  |  +-----+-----------------+-------------------+----------+  | |
|  |  |                       Core                           |  | |
|  |  |  App Lifecycle    Configuration                      |  | |
|  |  |  Container (DI)   Event Bus                          |  | |
|  |  |  Security Policy  Logger                             |  | |
|  |  +---------------------------+--------------------------+  | |
|  |                              |                             | |
|  |  +---------------------------+--------------------------+  | |
|  |  |                     Platform                         |  | |
|  |  |  Window Management   File System                     |  | |
|  |  |  Native WebView      System Integration              |  | |
|  |  |  Clipboard           Shell                           |  | |
|  |  +---------------------------------------------------------+  | |
|  +------------------------------------------------------------+  |
+-----------------------------------------------------------------+
```

---

## 모듈 정의

Loom은 7개의 모듈로 구성된다.

| 모듈 | 설명 | 의존성 |
|------|------|--------|
| **Core** | Configuration, Container, EventBus, Logger, SecurityPolicy | 없음 |
| **Bridge** | JS/Swift 간 양방향 통신, 메시지 직렬화, 라우팅 | Core |
| **Platform** | 플랫폼 추상화 프로토콜 (WindowManager, NativeWebView, FileSystem 등) | Core |
| **PlatformMacOS** | macOS 네이티브 구현 (WKWebView, AppKit) | Core, Platform |
| **Plugin** | 플러그인 시스템, PluginRegistry, 내장 플러그인 | Core, Bridge, Platform |
| **WebEngine** | 웹 렌더링 엔진 추상화, SDK 주입 | Core, Platform |
| **Loom** | 통합 진입점, LoomApp, LoomApplication | 전체 |

---

## 의존성 그래프

```
                    +--------+
                    |  Loom  |  (통합 진입점)
                    +---+----+
          +---------+---+-------+-----------+
          v         v   v       v           v
     +--------+ +------+ +--------+ +------------+
     | Plugin | |Bridge| |WebEngine| |PlatformMacOS|
     +--+--+--+ +--+---+ +--+--+--+ +------+-----+
        |  |  |    |        |  |           |
        |  |  +----+        |  |    +------+
        |  |                |  |    |
        v  v                v  v    v
     +------+          +----------+
     | Core |<---------| Platform |
     +------+          +----+-----+
                            |
                            v
                        +------+
                        | Core |
                        +------+
```

---

## 디렉토리 레이아웃

```
Loom/
+-- Package.swift
+-- Sources/
|   +-- Core/
|   |   +-- AppConfiguration.swift
|   |   +-- Application.swift
|   |   +-- Configuration.swift          # EntryPoint, WindowConfiguration
|   |   +-- Container.swift
|   |   +-- ContainerActor.swift
|   |   +-- EventBus.swift
|   |   +-- EventBusActor.swift
|   |   +-- Logger.swift
|   |   +-- PathSandbox.swift
|   |   +-- SecurityPolicy.swift
|   |   +-- URLSchemeWhitelist.swift
|   +-- Bridge/
|   |   +-- Bridge.swift
|   |   +-- BridgeActor.swift
|   |   +-- BridgeMessage.swift
|   |   +-- BridgeTransport.swift
|   |   +-- JSONMessageCodec.swift
|   |   +-- MessageCodec.swift
|   +-- Platform/
|   |   +-- Clipboard.swift
|   |   +-- FileSystem.swift
|   |   +-- FileWatcher.swift
|   |   +-- Menu.swift                   # MenuItem
|   |   +-- NativeWebView.swift
|   |   +-- PlatformProvider.swift
|   |   +-- Shell.swift
|   |   +-- SystemDialogs.swift
|   |   +-- SystemInfo.swift
|   |   +-- WindowHandle.swift
|   |   +-- WindowManager.swift
|   +-- PlatformMacOS/
|   |   +-- MacOSClipboard.swift
|   |   +-- MacOSDialogs.swift
|   |   +-- MacOSFileSystem.swift
|   |   +-- MacOSFileWatcher.swift
|   |   +-- MacOSMenu.swift
|   |   +-- MacOSPlatformProvider.swift
|   |   +-- MacOSShell.swift
|   |   +-- MacOSWebView.swift
|   |   +-- MacOSWindowManager.swift
|   +-- Plugin/
|   |   +-- Plugin.swift
|   |   +-- PluginBridgeConnector.swift
|   |   +-- PluginContext.swift
|   |   +-- PluginError.swift
|   |   +-- PluginMethod.swift
|   |   +-- PluginRegistry.swift
|   |   +-- PluginRegistryActor.swift
|   |   +-- Builtins/
|   |       +-- ClipboardPlugin.swift
|   |       +-- DialogPlugin.swift
|   |       +-- FileSystemPlugin.swift
|   |       +-- ProcessPlugin.swift
|   |       +-- ShellPlugin.swift
|   |       +-- PluginArgs.swift
|   |       +-- PlatformServiceStorage.swift
|   +-- WebEngine/
|   |   +-- BridgeSDKProvider.swift
|   |   +-- DefaultBridgeSDKProvider.swift
|   |   +-- DefaultWebEngine.swift
|   |   +-- WebEngine.swift
|   |   +-- WebEngineDelegate.swift
|   |   +-- Resources/
|   |       +-- bridge-sdk.js
|   |       +-- loom.d.ts
|   +-- Loom/
|       +-- LoomApp.swift
|       +-- LoomApplication.swift
|       +-- LoomPluginContext.swift
|       +-- PrintLogger.swift
|       +-- WebEngineTransport.swift
+-- Tests/
|   +-- LoomTestKit/
|   +-- CoreTests/
|   +-- BridgeTests/
|   +-- PlatformTests/
|   +-- PluginTests/
|   +-- WebEngineTests/
|   +-- LoomTests/
+-- sample/
+-- docs/
```

---

## 데이터 흐름

### JS -> Swift 호출 흐름 (Request/Response)

```
JS (Frontend)                    Swift (Backend)
--------------                   ---------------

loom.invoke("filesystem.readFile",
  { path: "/tmp/a.txt" })
        |
        v
window.webkit.messageHandlers
  .loom.postMessage(json)
        |
        v
+-------------------+
|    WebEngine      |  JS 메시지 수신
| (DefaultWebEngine)|
+--------+----------+
         | BridgeMessage 디코딩
         v
+-------------------+
|     Bridge        |  method 기반 라우팅
|   (BridgeActor)   |  "plugin.filesystem.readFile"
+--------+----------+
         | PluginBridgeConnector가 등록한 핸들러 호출
         v
+-------------------+
| Plugin(filesystem)|  파일 읽기 수행
|                   |  Platform.FileSystem 사용
+--------+----------+
         | 결과 반환
         v
+-------------------+
|     Bridge        |  응답 BridgeMessage 생성
|   (BridgeActor)   |  (동일 correlation ID)
+--------+----------+
         | BridgeTransport.sendToWeb()
         v
+-------------------+
|WebEngineTransport |  evaluateJavaScript()
+--------+----------+
         |
         v
JS Promise resolve
  { content: "..." }
```

### Swift -> JS 이벤트 흐름 (Push)

```
Swift (Backend)                  JS (Frontend)
---------------                  -------------

Plugin에서 이벤트 발생
        |
        v
+-------------------+
|  PluginContext     |  emit(event:data:)
+--------+----------+
         |
         v
+-------------------+
|     Bridge        |  이벤트 BridgeMessage 생성
|   (BridgeActor)   |  kind: .nativeEvent
+--------+----------+
         | BridgeTransport.sendToWeb()
         v
+-------------------+
|WebEngineTransport |  evaluateJavaScript()
+--------+----------+
         |
         v
window.__loom__.receive(base64)
         |
         v
등록된 리스너 콜백 실행
loom.on("eventName", cb)
```

### 메시지 포맷

모든 메시지는 `BridgeMessage` 구조를 따른다.

```json
{
  "id": "msg_a1b2c3d4",
  "method": "plugin.filesystem.readFile",
  "payload": "eyJwYXRoIjoiL3RtcC9hLnR4dCJ9",
  "kind": "request"
}
```

- `id`: UUID 기반 고유 식별자 (요청-응답 상관관계)
- `method`: 점(.)으로 구분된 네임스페이스 경로
- `payload`: Base64 인코딩된 JSON 데이터 (또는 null)
- `kind`: `request`, `response`, `nativeEvent`, `error`, `webEvent` 중 하나

---

## 동시성 모델

Loom은 Swift 6.0의 엄격한 동시성 검사(Strict Concurrency)를 준수한다.

### Actor 기반 상태 격리

공유 가변 상태를 가지는 컴포넌트는 actor로 구현한다.

```swift
public actor BridgeActor: Bridge {
    private var handlers: [String: @Sendable (Data?) async throws -> Data?] = [:]
    private let transport: any BridgeTransport
    private let codec: any MessageCodec
    // ...
}

public actor ContainerActor: Container {
    private var entries: [ObjectIdentifier: Entry] = [:]
    private var singletonCache: [ObjectIdentifier: any Sendable] = [:]
    // ...
}

public actor PluginRegistryActor: PluginRegistry {
    private var orderedKeys: [String] = []
    private var plugins: [String: any Plugin] = [:]
    // ...
}
```

### Sendable 준수 전략

| 타입 분류 | Sendable 전략 |
|----------|--------------|
| 값 타입 (struct, enum) | 모든 프로퍼티가 Sendable이면 자동 준수 |
| 프로토콜 | 선언 시 `Sendable` 상속 명시 |
| 클로저 | `@Sendable` 어트리뷰트 필수 |
| Actor | 암묵적으로 Sendable |
| 클래스 | `final class` + `@unchecked Sendable` + 내부 동기화 |

### @MainActor 격리

UI 관련 작업(윈도우 생성, WebView 조작)은 `@MainActor`로 격리한다.

```swift
@MainActor
public final class MacOSWebView: NSObject, NativeWebView, @unchecked Sendable {
    private let webView: WKWebView
    // WKWebView 조작은 모두 Main Actor에서 수행
}

@MainActor
public final class MacOSPlatformProvider: PlatformProvider, @unchecked Sendable {
    // ...
}
```

`LoomApp.run()`도 `@MainActor`로 마킹되어 있어 UI 초기화가 메인 스레드에서 수행된다.

### @unchecked Sendable 사용 지침

가변 상태가 있지만 actor로 만들기 어려운 경우 `final class` + `@unchecked Sendable` + 내부 잠금으로 안전성을 보장한다.

```swift
// LoomApp: NSLock으로 런타임 상태 보호
public final class LoomApp: Application, @unchecked Sendable {
    private let _lock = NSLock()
    private var _runtimeState = RuntimeState()
}

// DefaultWebEngine: NSLock으로 delegate 보호
public final class DefaultWebEngine: WebEngine, @unchecked Sendable {
    private var _delegate: (any WebEngineDelegate)?
    private let _delegateLock = NSLock()
}
```

### Structured Concurrency

플러그인 초기화는 등록 순서를 보장하면서 순차적으로 수행되며, 하나라도 실패하면 이미 초기화된 플러그인을 롤백(dispose)한다.

```swift
func initializeAll(context: any PluginContext) async throws {
    var initialized: [any Plugin] = []
    do {
        for key in orderedKeys {
            guard let plugin = plugins[key] else { continue }
            try await plugin.initialize(context: context)
            initialized.append(plugin)
        }
    } catch {
        for plugin in initialized {
            await plugin.dispose()
        }
        throw error
    }
}
```

---

## 다음 단계

- [플러그인 시스템](04-plugin-system.md) - Plugin 프로토콜 상세
- [플랫폼 레이어](07-platform-layer.md) - PlatformProvider와 macOS 구현체
