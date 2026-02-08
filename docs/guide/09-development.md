# 개발 환경

개발 환경 설정, Hot Reload, DevTools, 디버깅 팁.

---

## 개발 모드

Loom은 두 가지 개발 모드를 지원한다.

| 모드 | 진입점 | Hot Reload 방식 | 적합한 상황 |
|------|--------|----------------|------------|
| 로컬 파일 | `.file(URL)` | FileWatcher (전체 리로드) | 정적 HTML/CSS/JS |
| 개발 서버 | `.remote(URL)` | 서버측 HMR | React/Vue/Svelte 프로젝트 |

---

## 개발 서버 연동 (HMR)

Vite, Webpack 등의 개발 서버를 사용하면 HMR(Hot Module Replacement)은 서버가 처리한다.

```swift
let config = AppConfiguration(
    name: "My App",
    entry: .bundle(resource: "web/index", extension: "html", in: .module),
    debugEntry: .remote(URL(string: "http://localhost:5173")!) // Vite
)
```

### Vite 설정

```bash
npm create vite@latest frontend -- --template svelte
cd frontend
npm install
npm run dev  # http://localhost:5173
```

```swift
debugEntry: .remote(URL(string: "http://localhost:5173")!)
```

### Webpack / 기타

```swift
debugEntry: .remote(URL(string: "http://localhost:8080")!)  // Webpack
debugEntry: .remote(URL(string: "http://localhost:3000")!)  // 기타
```

---

## FileWatcher (로컬 파일 모드)

로컬 파일을 직접 로드하는 경우, `FileWatcher`가 파일 변경을 감시하고 웹 페이지를 자동 리로드한다.

### 활성화 조건

- `isDebug == true` (DEBUG 빌드)
- `resolvedEntry`가 `.file` 케이스

```swift
let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

let config = AppConfiguration(
    name: "My App",
    entry: .bundle(resource: "web/index", extension: "html", in: .module),
    debugEntry: .file(sourceURL.appendingPathComponent("Resources/web/index.html"))
)
// DEBUG 빌드에서 shouldWatchFiles == true
// FileWatcher가 해당 디렉토리의 변경을 감시
```

FileWatcher는 진입점 HTML 파일의 상위 디렉토리를 감시한다. 파일이 변경되면 `webEngine.reload()`가 호출된다.

---

## DevTools / Web Inspector

DEBUG 빌드에서 `MacOSWebView`는 자동으로 `webView.isInspectable = true`를 설정한다.

### 사용 방법

1. Safari 메뉴 > 설정 > 고급 > "웹 개발자용 기능 표시" 활성화
2. Loom 앱 실행
3. Safari 메뉴 > 개발자용 > [앱 이름] 선택
4. Web Inspector가 열린다

Web Inspector에서 DOM 검사, 네트워크, 콘솔, 성능 프로파일링 등을 사용할 수 있다.

---

## console.log -> Swift Logger 포워딩

DEBUG 빌드에서 `enableConsoleForwarding(logger:)`가 자동으로 활성화된다. JavaScript의 `console.log/warn/error/info`가 Swift의 `Logger`로 포워딩된다.

```
[JS:log] Hello from JavaScript
[JS:warn] This is a warning
[JS:error] Something went wrong
[JS:info] Information message
```

이 기능은 `LoomApp.run()` 내부에서 자동으로 설정된다:

```swift
#if os(macOS)
if let macWebView = nativeWebView as? MacOSWebView {
    macWebView.enableConsoleForwarding(logger: logger)
}
#endif
```

Xcode 콘솔에서 JS와 Swift 로그를 한 곳에서 확인할 수 있어 디버깅이 편리하다.

---

## 로그 레벨 설정

`AppConfiguration`의 `logLevel`로 최소 로그 레벨을 설정한다.

```swift
AppConfiguration(
    name: "My App",
    entry: .bundle(resource: "index", extension: "html"),
    logLevel: .info  // .debug, .info, .warning, .error
)
```

`PrintLogger`는 설정된 레벨 미만의 로그를 무시한다.

---

## 디버깅 팁

### 1. 콘솔 출력 확인

DEBUG 빌드에서 Loom은 진입점과 파일 감시 상태를 출력한다.

```
[Loom] 진입점: http://localhost:5173
[Loom] 파일 감시: false
```

### 2. 개발/릴리스 진입점 분리

`debugEntry`를 설정하여 개발과 프로덕션 진입점을 분리한다. `validate()`가 `entry`에 localhost URL이 설정된 경우 경고한다.

```swift
let config = AppConfiguration(
    name: "My App",
    entry: .bundle(resource: "web/index", extension: "html", in: .module),
    debugEntry: .remote(URL(string: "http://localhost:5173")!)
)
```

### 3. 전체 개발 워크플로우

```bash
# 터미널 1: 프론트엔드 개발 서버
cd frontend && npm run dev

# 터미널 2: Swift 앱 실행
swift run --package-path sample LoomSample
```

프론트엔드 코드를 수정하면 HMR이 자동으로 반영된다.

---

## 다음 단계

- [테스트](10-testing.md) - 테스트 전략과 LoomTestKit
- [빌드 및 명령어](11-build-and-commands.md) - 빌드와 배포
