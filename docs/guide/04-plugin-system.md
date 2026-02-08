# 플러그인 시스템

Loom의 핵심 확장 메커니즘: Plugin 프로토콜, PluginMethod, PluginContext, 생명주기.

---

## Plugin 프로토콜

커스텀 플러그인을 작성하려면 `Plugin` 프로토콜을 구현한다.

```swift
public protocol Plugin: Sendable {
    var name: String { get }
    func initialize(context: any PluginContext) async throws
    func methods() async -> [PluginMethod]
    func dispose() async
}
```

| 멤버 | 설명 |
|------|------|
| `name` | 플러그인 고유 이름. JS에서 `pluginName.methodName` 형태로 호출할 때의 네임스페이스 |
| `initialize(context:)` | 초기화 시 호출. `PluginContext`로 프레임워크 서비스에 접근 |
| `methods()` | Bridge에 등록할 메서드 목록 반환. `async`이므로 actor 플러그인에서 자연스럽게 사용 가능 |
| `dispose()` | 앱 종료 시 리소스 정리 |

`initialize(context:)`와 `dispose()`는 기본 빈 구현이 제공된다.

---

## PluginMethod

각 메서드는 이름과 핸들러로 구성된다.

### 기본 초기화

핸들러는 JSON 문자열을 받아 JSON 문자열을 반환한다.

```swift
public struct PluginMethod: Sendable {
    public let name: String
    public let handler: @Sendable (String) async throws -> String
}
```

### 타입-세이프 convenience init

JSON 디코딩/인코딩을 자동으로 처리하는 편의 초기화가 제공된다.

```swift
// Decodable 인자 -> Encodable 결과
PluginMethod(name: "readFile") { (args: ReadFileArgs) -> ReadFileResult in
    // args는 자동으로 JSON 디코딩됨
    // 반환값은 자동으로 JSON 인코딩됨
    return ReadFileResult(content: "...")
}

// 인자 없음 -> Encodable 결과
PluginMethod(name: "readText") { () -> [String: String] in
    return ["text": "clipboard content"]
}
```

내부 구현:

```swift
extension PluginMethod {
    public init<Args: Decodable & Sendable, Result: Encodable & Sendable>(
        name: String,
        handler: @escaping @Sendable (Args) async throws -> Result
    ) {
        self.name = name
        self.handler = { payload in
            let args = try JSONDecoder().decode(Args.self, from: Data(payload.utf8))
            let result = try await handler(args)
            let data = try JSONEncoder().encode(result)
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }
}
```

---

## PluginContext

플러그인에 주입되는 컨텍스트로, 프레임워크 핵심 서비스에 접근할 수 있다.

```swift
public protocol PluginContext: Sendable {
    var container: any ContainerResolver { get }
    var eventBus: any EventBus { get }
    var logger: any Logger { get }
    func emit(event: String, data: String) async throws
}
```

| 멤버 | 설명 |
|------|------|
| `container` | 의존성 주입 컨테이너 (읽기 전용). `resolve()`로 플랫폼 서비스를 가져올 수 있다 |
| `eventBus` | 모듈 간 내부 이벤트 전파용 이벤트 버스 |
| `logger` | 로깅 인터페이스 |
| `emit(event:data:)` | Swift에서 JavaScript로 이벤트를 푸시 |

### Encodable emit 확장

`Encodable` 타입을 직접 전달하는 편의 메서드도 제공된다.

```swift
extension PluginContext {
    public func emit<T: Encodable & Sendable>(event: String, data: T) async throws
}
```

---

## 플러그인 생명주기

```
register() --> initializeAll() --> [활성 상태] --> disposeAll()
                     |                   |
                     v                   v
         PluginBridgeConnector     메서드 호출 처리
         가 Bridge에 메서드 등록
```

1. **등록(Register)**: `PluginRegistryActor`에 인스턴스 등록
2. **초기화(Initialize)**: `PluginContext` 주입, 등록 순서대로 초기화
3. **Bridge 연결**: `PluginBridgeConnector.connect()`로 메서드를 Bridge에 등록
4. **활성(Active)**: JS 호출을 수신하고 처리
5. **해제(Dispose)**: 앱 종료 시 리소스 정리

---

## 커스텀 플러그인 예시

### Stateless 플러그인 (struct)

```swift
import Foundation
import Core
import Plugin

public struct GreeterPlugin: Plugin {
    public let name = "greeter"

    public init() {}

    public func methods() async -> [PluginMethod] {
        [
            PluginMethod(name: "hello") { (args: HelloArgs) -> HelloResult in
                HelloResult(message: "Hello, \(args.name)! Welcome to Loom.")
            }
        ]
    }
}

private struct HelloArgs: Decodable, Sendable { let name: String }
private struct HelloResult: Encodable, Sendable { let message: String }
```

JavaScript에서 호출:

```javascript
const result = await loom.invoke("greeter.hello", { name: "Loom" });
console.log(result.message); // "Hello, Loom! Welcome to Loom."
```

### 이벤트를 발행하는 플러그인 (class)

`PluginContext`를 보관하여 이벤트를 발행할 수 있다. 가변 상태가 있으므로 `final class` + `@unchecked Sendable`을 사용한다.

```swift
import Foundation
import Core
import Plugin

public final class EventDemoPlugin: Plugin, @unchecked Sendable {
    public let name = "eventDemo"
    private var context: (any PluginContext)?

    public init() {}

    public func initialize(context: any PluginContext) async throws {
        self.context = context
    }

    public func methods() async -> [PluginMethod] {
        [
            PluginMethod(name: "emit") { [weak self] payload in
                struct Args: Codable { let event: String; let data: String? }
                let args = try JSONDecoder().decode(Args.self, from: Data(payload.utf8))
                guard let context = self?.context else {
                    throw PluginError.notInitialized
                }
                try await context.emit(event: args.event, data: args.data ?? "{}")
                return "{}"
            }
        ]
    }

    public func dispose() async {
        context = nil
    }
}
```

JavaScript에서 이벤트 수신:

```javascript
const unsubscribe = loom.on("myEvent", (data) => {
    console.log("이벤트 수신:", data);
});

await loom.invoke("eventDemo.emit", {
    event: "myEvent",
    data: '{"message": "hello from swift"}'
});

unsubscribe();
```

---

## 플러그인 등록

`LoomApplication`의 `plugins` 프로퍼티에서 반환하거나 `LoomApp` 생성 시 전달한다.

```swift
@main
struct MyApp: LoomApplication {
    var configuration: AppConfiguration { /* ... */ }

    var plugins: [any Plugin] {
        [
            FileSystemPlugin(securityPolicy: sandbox),
            DialogPlugin(),
            ClipboardPlugin(),
            ShellPlugin(securityPolicy: sandbox),
            ProcessPlugin(securityPolicy: sandbox),
            GreeterPlugin()       // 커스텀
        ]
    }
}
```

---

## PluginError

플러그인에서 사용할 수 있는 에러 타입이다.

```swift
public enum PluginError: Error, Sendable, Equatable, LocalizedError {
    case invalidArguments       // 잘못된 인자
    case unsupportedPlatform    // 지원하지 않는 플랫폼
    case notInitialized         // 초기화되지 않음
    case blockedURLScheme(String)  // 허용되지 않은 URL 스킴
    case blockedPath(String)    // 허용되지 않은 경로
    case custom(String)         // 사용자 정의 에러
}
```

---

## 다음 단계

- [내장 플러그인](05-builtin-plugins.md) - FileSystem, Dialog, Clipboard, Shell, Process
- [Bridge SDK](06-bridge-sdk.md) - JavaScript SDK API
