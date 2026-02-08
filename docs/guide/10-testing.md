# 테스트

테스트 전략, LoomTestKit, Mock/Stub 활용법, 테스트 실행.

---

## 테스트 프레임워크

Loom은 Swift Testing 프레임워크(`@Test`, `#expect`)를 사용한다.

```swift
import Testing

@Test func testSomething() {
    #expect(1 + 1 == 2)
}
```

---

## 테스트 타겟

| 타겟 | 테스트 범위 |
|------|-----------|
| `CoreTests` | Configuration, Container, EventBus, PathSandbox, URLSchemeWhitelist |
| `BridgeTests` | BridgeMessage, BridgeActor, JSONMessageCodec |
| `PlatformTests` | MacOSFileSystem, MacOSFileWatcher, WebView cleanup, MenuItem |
| `PluginTests` | Plugin 프로토콜, PluginRegistry, 내장 플러그인 (FileSystem, Dialog, Clipboard, Shell, Process) |
| `WebEngineTests` | DefaultWebEngine, DefaultBridgeSDKProvider |
| `LoomTests` | LoomApp 통합 테스트, LoomPluginContext, WebEngineTransport |

---

## LoomTestKit

테스트 공유 라이브러리로, 프로토콜 기반 설계를 활용한 Mock과 Stub을 제공한다.

### Mock (행위 검증용)

호출 기록을 추적하여 특정 메서드가 호출되었는지 검증한다.

| Mock | 대상 프로토콜 |
|------|-------------|
| `MockBridge` | `Bridge` |
| `MockBridgeTransport` | `BridgeTransport` |
| `MockPlugin` | `Plugin` |
| `MockPluginContext` | `PluginContext` |
| `MockNativeWebView` | `NativeWebView` |
| `MockWindowManager` | `WindowManager` |
| `MockFileWatcher` | `FileWatcher` |

### Stub (상태 검증용)

간단한 반환값을 제공하여 의존성을 대체한다.

| Stub | 대상 프로토콜 |
|------|-------------|
| `StubContainer` | `Container` |
| `StubEventBus` | `EventBus` |
| `StubLogger` | `Logger` |
| `StubFileSystem` | `FileSystem` |
| `StubSystemDialogs` | `SystemDialogs` |
| `StubClipboard` | `Clipboard` |
| `StubShell` | `Shell` |

### SpyLogger

로그 메시지를 캡처하여 검증할 수 있는 로거이다.

---

## 테스트 작성 예시

### 플러그인 테스트

`MockPluginContext`를 사용하여 플러그인을 독립적으로 테스트한다.

```swift
import Testing
import Plugin
import Core
@testable import LoomTestKit

@Test func testGreeterPlugin() async throws {
    let plugin = GreeterPlugin()
    let context = MockPluginContext(
        container: StubContainer(),
        eventBus: StubEventBus(),
        logger: StubLogger()
    )
    try await plugin.initialize(context: context)

    let methods = await plugin.methods()
    let hello = methods.first { $0.name == "hello" }!
    let result = try await hello.handler("{\"name\": \"Loom\"}")
    #expect(result.contains("Hello"))
}
```

### Configuration 테스트

`AppConfiguration`의 internal 초기화를 활용하면 `isDebug`를 명시적으로 제어할 수 있다.

```swift
@Test func testDebugResolvedEntry() {
    let config = AppConfiguration(
        name: "Test",
        entry: .bundle(resource: "index", extension: "html"),
        debugEntry: .file(URL(fileURLWithPath: "/test/index.html")),
        isDebug: true
    )
    #expect(config.resolvedEntry == .file(URL(fileURLWithPath: "/test/index.html")))
    #expect(config.shouldWatchFiles)
}

@Test func testValidateWarning() {
    let config = AppConfiguration(
        name: "Test",
        entry: .remote(URL(string: "http://localhost:5173")!)
    )
    let warnings = config.validate()
    #expect(!warnings.isEmpty)
}
```

### Bridge 테스트

```swift
@Test func testBridgeRouting() async throws {
    let transport = MockBridgeTransport()
    let codec = JSONMessageCodec()
    let bridge = BridgeActor(transport: transport, codec: codec)

    var called = false
    await bridge.register(method: "test.method") { _ in
        called = true
        return nil
    }

    let message = BridgeMessage(
        id: "test-1",
        method: "test.method",
        payload: nil,
        kind: .request
    )
    await bridge.receive(message)
    #expect(called)
}
```

---

## 테스트 실행 명령어

```bash
# 프레임워크 전체 테스트
swift test

# 특정 테스트 타겟만 실행
swift test --filter CoreTests
swift test --filter BridgeTests
swift test --filter PluginTests
swift test --filter PlatformTests
swift test --filter WebEngineTests
swift test --filter LoomTests

# 샘플 앱 테스트
swift test --package-path sample
```

---

## 다음 단계

- [빌드 및 명령어](11-build-and-commands.md) - 빌드 명령어 전체 요약
- [아키텍처](03-architecture.md) - 모듈 간 의존성과 테스트 격리
