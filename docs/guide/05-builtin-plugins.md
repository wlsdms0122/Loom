# 내장 플러그인

Loom이 제공하는 5가지 내장 플러그인: FileSystem, Dialog, Clipboard, Shell, Process.

---

## FileSystemPlugin

파일 시스템 읽기, 쓰기, 존재 확인, 디렉토리 조회, 삭제 기능을 제공한다.

- **이름**: `filesystem`
- **SecurityPolicy 필수**: `init(securityPolicy:)`로 생성해야 한다

```swift
FileSystemPlugin(securityPolicy: PathSandbox(allowedDirectories: ["/tmp", "/Users/me/data"]))
```

### 메서드

| 메서드 | 설명 | 인자 | 반환 |
|-------|------|------|------|
| `readFile` | 파일을 Base64로 읽기 | `{ path: string }` | `{ content: string }` |
| `writeFile` | 파일에 쓰기 | `{ path: string, content: string }` | `{}` |
| `exists` | 파일/디렉토리 존재 확인 | `{ path: string }` | `{ exists: boolean }` |
| `readDir` | 디렉토리 항목 목록 | `{ path: string }` | `{ entries: string[] }` |
| `remove` | 파일/디렉토리 삭제 | `{ path: string }` | `{}` |

`writeFile`의 `content`는 Base64 인코딩된 데이터 또는 일반 텍스트를 받을 수 있다. Base64 디코딩이 가능하면 바이너리로, 아니면 UTF-8 텍스트로 저장된다.

```javascript
const result = await loom.invoke("filesystem.readFile", { path: "/tmp/hello.txt" });
console.log(result.content); // Base64 인코딩된 내용

await loom.invoke("filesystem.writeFile", {
    path: "/tmp/output.txt",
    content: "Hello, Loom!"
});

const { exists } = await loom.invoke("filesystem.exists", { path: "/tmp/hello.txt" });
const { entries } = await loom.invoke("filesystem.readDir", { path: "/tmp" });
await loom.invoke("filesystem.remove", { path: "/tmp/output.txt" });
```

---

## DialogPlugin

macOS 네이티브 대화상자(NSOpenPanel, NSSavePanel, NSAlert)를 제공한다.

- **이름**: `dialog`
- SecurityPolicy 불필요

```swift
DialogPlugin()
```

### 메서드

| 메서드 | 설명 | 인자 | 반환 |
|-------|------|------|------|
| `showAlert` | 알림 대화상자 표시 | `{ title, message?, style? }` | `{ response: "ok" \| "cancel" }` |
| `openFile` | 파일 열기 대화상자 | `{ title?, allowedTypes?, multiple?, directories? }` | `{ paths: string[] }` |
| `saveFile` | 파일 저장 대화상자 | `{ title?, defaultName? }` | `{ path: string }` |

`showAlert`의 `style`에는 `"informational"`, `"warning"`, `"critical"` 중 하나를 지정한다. 기본값은 `"informational"`이다.

```javascript
const { response } = await loom.invoke("dialog.showAlert", {
    title: "확인",
    message: "파일을 저장하시겠습니까?",
    style: "warning"
});

const { paths } = await loom.invoke("dialog.openFile", {
    title: "파일 선택",
    allowedTypes: ["txt", "md"],
    multiple: true,
    directories: false
});

const { path } = await loom.invoke("dialog.saveFile", {
    title: "다른 이름으로 저장",
    defaultName: "document.txt"
});
```

---

## ClipboardPlugin

시스템 클립보드에 대한 텍스트 읽기/쓰기 기능을 제공한다.

- **이름**: `clipboard`
- SecurityPolicy 불필요

```swift
ClipboardPlugin()
```

### 메서드

| 메서드 | 설명 | 인자 | 반환 |
|-------|------|------|------|
| `readText` | 클립보드에서 텍스트 읽기 | (없음) | `{ text: string }` |
| `writeText` | 클립보드에 텍스트 쓰기 | `{ text: string }` | `{}` |

```javascript
const { text } = await loom.invoke("clipboard.readText");
await loom.invoke("clipboard.writeText", { text: "복사할 텍스트" });
```

---

## ShellPlugin

기본 브라우저로 URL을 열거나 Finder에서 경로를 여는 기능을 제공한다.

- **이름**: `shell`
- **SecurityPolicy 필수**: `init(securityPolicy:)`로 생성해야 한다
- URL 스킴 화이트리스트 적용

```swift
ShellPlugin(securityPolicy: PathSandbox(allowedDirectories: ["/Users/me"]))
// 또는 URLSchemeWhitelist를 직접 지정
ShellPlugin(
    securityPolicy: PathSandbox(allowedDirectories: ["/Users/me"]),
    urlSchemeWhitelist: URLSchemeWhitelist(schemes: ["http", "https"])
)
```

### 메서드

| 메서드 | 설명 | 인자 | 반환 |
|-------|------|------|------|
| `openURL` | 기본 브라우저에서 URL 열기 | `{ url: string }` | `{}` |
| `openPath` | Finder에서 경로 열기 | `{ path: string }` | `{}` |

`openURL`은 `URLSchemeWhitelist`로 허용된 스킴인지 검증한다. `openPath`는 `SecurityPolicy`로 경로를 검증한다.

```javascript
await loom.invoke("shell.openURL", { url: "https://github.com" });
await loom.invoke("shell.openPath", { path: "/Users/dev/Documents" });
```

---

## ProcessPlugin

외부 프로세스를 실행하는 플러그인이다.

- **이름**: `process`
- **SecurityPolicy 필수**: `init(securityPolicy:)`로 생성해야 한다

```swift
ProcessPlugin(securityPolicy: PathSandbox(allowedDirectories: ["/usr/bin", "/usr/local/bin"]))
```

### 메서드

| 메서드 | 설명 | 인자 | 반환 |
|-------|------|------|------|
| `execute` | 외부 프로세스 실행 | `{ command, arguments?, cwd? }` | `{ exitCode, stdout, stderr }` |

실행 파일 경로(`command`)는 SecurityPolicy로 검증된다. 허용된 디렉토리 내의 실행 파일만 실행할 수 있다.

```javascript
const result = await loom.invoke("process.execute", {
    command: "/usr/bin/git",
    arguments: ["status"],
    cwd: "/Users/dev/project"
});
console.log(result.exitCode); // 0
console.log(result.stdout);   // git status 출력
console.log(result.stderr);   // 에러 출력 (있다면)
```

---

## SecurityPolicy와 내장 플러그인

`FileSystemPlugin`, `ShellPlugin`, `ProcessPlugin`은 `SecurityPolicy`를 필수로 요구한다. 인자 없는 `init()`은 `@available(*, unavailable)`로 차단되어 있다.

```swift
// 사용 가능한 SecurityPolicy 구현체
let sandbox = PathSandbox(
    allowedDirectories: ["/tmp", "/Users/me/data"],
    allowedSchemes: ["http", "https"]
)

// 플러그인 생성
FileSystemPlugin(securityPolicy: sandbox)
ShellPlugin(securityPolicy: sandbox)
ProcessPlugin(securityPolicy: sandbox)
```

SecurityPolicy에 대한 자세한 내용은 [보안](08-security.md)을 참조한다.

---

## 다음 단계

- [Bridge SDK](06-bridge-sdk.md) - JavaScript SDK API 전체 레퍼런스
- [보안](08-security.md) - SecurityPolicy, PathSandbox 상세
