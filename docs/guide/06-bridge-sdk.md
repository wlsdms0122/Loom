# Bridge SDK

JavaScript SDK API: loom.invoke(), loom.on(), loom.once(), loom.emit(), loom.setDefaultTimeout().

---

## 개요

Loom은 웹 페이지 로드 시 `bridge-sdk.js`를 자동으로 주입한다. 이 SDK는 `window.loom` 객체를 통해 Swift 플러그인과 통신하는 API를 제공한다.

---

## loom.ready

SDK 초기화가 완료되면 resolve되는 Promise이다.

```javascript
await loom.ready;
// 이후 loom.invoke()를 안전하게 호출할 수 있다
```

---

## loom.invoke(method, params)

플러그인 메서드를 호출하고 결과를 Promise로 반환한다.

```javascript
const result = await loom.invoke("pluginName.methodName", { key: "value" });
const text = await loom.invoke("clipboard.readText");
```

기본 타임아웃은 30초(30,000ms)이다. 타임아웃 내에 응답이 없으면 Promise가 reject된다.

### 메서드 명명 규칙

메서드 이름은 `pluginName.methodName` 형태이다. SDK 내부에서 `plugin.` 접두사를 자동으로 추가한다.

| JavaScript 호출 | Bridge 내부 경로 |
|----------------|-----------------|
| `loom.invoke("filesystem.readFile", ...)` | `plugin.filesystem.readFile` |
| `loom.invoke("dialog.openFile", ...)` | `plugin.dialog.openFile` |
| `loom.invoke("greeter.hello", ...)` | `plugin.greeter.hello` |

### 에러 처리

호출이 실패하면 Promise가 `Error` 객체로 reject된다. 에러 객체에는 구조화된 정보가 포함된다.

```javascript
try {
    const result = await loom.invoke("filesystem.readFile", { path: "/nonexistent" });
} catch (error) {
    console.error(error.message);  // 에러 메시지
    console.error(error.code);     // "HANDLER_ERROR" | "METHOD_NOT_FOUND"
    console.error(error.plugin);   // 플러그인 이름 (있을 경우)
    console.error(error.method);   // 메서드 경로
}
```

Swift 측의 `ErrorPayload` 구조:

```swift
public struct ErrorPayload: Codable, Sendable {
    public let code: String
    public let message: String
    public let plugin: String?
    public let method: String?
}
```

---

## loom.on(event, callback)

Swift에서 발행하는 이벤트를 구독한다. 반환값은 구독을 해제하는 함수이다.

```javascript
const unsubscribe = loom.on("fileChanged", (data) => {
    console.log("파일 변경됨:", data);
});

// 구독 해제
unsubscribe();
```

여러 리스너를 동일 이벤트에 등록할 수 있다.

---

## loom.once(event, callback)

이벤트를 한 번만 수신한다. 호출 후 자동으로 구독이 해제된다.

```javascript
loom.once("appReady", (data) => {
    console.log("앱 준비 완료:", data);
});
```

---

## loom.emit(event, data)

JavaScript에서 Swift로 단방향 이벤트를 전송한다. `invoke()`와 달리 응답을 기다리지 않는다 (fire-and-forget).

```javascript
// 이벤트만 전송
loom.emit("ui.buttonClicked");

// 데이터와 함께 전송
loom.emit("editor.contentChanged", { length: 42 });
```

Swift 측에서는 `Bridge.onEvent(name:handler:)`로 이벤트를 수신한다.

---

## loom.setDefaultTimeout(ms)

`invoke()` 호출의 기본 타임아웃을 변경한다. 초기 기본값은 30,000ms이다.

```javascript
loom.setDefaultTimeout(60000); // 60초로 변경
```

---

## 내부 메시지 흐름

SDK는 내부적으로 JSON 메시지를 Base64로 인코딩하여 `window.webkit.messageHandlers.loom.postMessage()`를 통해 Swift로 전송한다. 응답은 Swift가 `window.__loom__.receive()`를 호출하여 전달한다.

```
요청:  JS -> loom.invoke() -> postMessage(JSON) -> Swift BridgeActor.receive()
응답:  Swift -> BridgeActor.send() -> evaluateJavaScript() -> __loom__.receive() -> Promise resolve
이벤트(S->JS): Swift -> emit() -> BridgeActor.send(.nativeEvent) -> __loom__.receive() -> listeners 호출
이벤트(JS->S): JS -> loom.emit() -> postMessage(JSON, kind:"webEvent") -> BridgeActor.receive()
```

---

## loom.d.ts 타입 정의

Loom은 TypeScript 프로젝트를 위한 `loom.d.ts` 타입 정의 파일을 제공한다. `Sources/WebEngine/Resources/loom.d.ts`에 위치하며, 빌드 시 번들에 포함된다.

주요 타입:

```typescript
interface LoomSDK {
    ready: Promise<void>;
    invoke(method: 'filesystem.readFile', params: Loom.ReadFileParams): Promise<Loom.ReadFileResult>;
    invoke(method: 'filesystem.writeFile', params: Loom.WriteFileParams): Promise<void>;
    invoke(method: 'filesystem.exists', params: Loom.ExistsParams): Promise<Loom.ExistsResult>;
    invoke(method: 'filesystem.readDir', params: Loom.ReadDirParams): Promise<Loom.ReadDirResult>;
    invoke(method: 'filesystem.remove', params: Loom.RemoveParams): Promise<void>;
    invoke(method: 'dialog.showAlert', params: Loom.ShowAlertParams): Promise<Loom.ShowAlertResult>;
    invoke(method: 'dialog.openFile', params?: Loom.OpenFileParams): Promise<Loom.OpenFileResult>;
    invoke(method: 'dialog.saveFile', params?: Loom.SaveFileParams): Promise<Loom.SaveFileResult>;
    invoke(method: 'clipboard.readText'): Promise<Loom.ReadTextResult>;
    invoke(method: 'clipboard.writeText', params: Loom.WriteTextParams): Promise<void>;
    invoke(method: 'process.execute', params: Loom.ExecuteParams): Promise<Loom.ExecuteResult>;
    invoke(method: 'shell.openURL', params: Loom.OpenURLParams): Promise<void>;
    invoke(method: 'shell.openPath', params: Loom.OpenPathParams): Promise<void>;
    invoke(method: string, params?: any): Promise<any>;

    emit(event: string, data?: any): void;
    on(event: string, callback: (data: any) => void): () => void;
    once(event: string, callback: (data: any) => void): () => void;
    setDefaultTimeout(ms: number): void;
}

declare const loom: LoomSDK;
```

TypeScript 프로젝트에서 이 파일을 `tsconfig.json`의 타입 경로에 추가하면 `loom.invoke()` 호출 시 타입 자동 완성을 사용할 수 있다.

---

## 다음 단계

- [내장 플러그인](05-builtin-plugins.md) - 각 플러그인의 메서드 레퍼런스
- [플러그인 시스템](04-plugin-system.md) - 커스텀 플러그인 작성
