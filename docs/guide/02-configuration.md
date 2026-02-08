# 설정

Loom의 설정 체계: AppConfiguration, EntryPoint, WindowConfiguration, MenuItem.

---

## EntryPoint

웹 콘텐츠의 진입점을 나타내는 열거형이다.

```swift
public enum EntryPoint: Sendable, Equatable {
    case bundle(resource: String, extension: String, in: Bundle = .main)
    case file(URL)
    case remote(URL)
}
```

### bundle -- 번들 리소스

Swift Package 또는 앱 번들에 포함된 리소스 파일을 진입점으로 지정한다.

```swift
let entry = EntryPoint.bundle(resource: "index", extension: "html")
let entry = EntryPoint.bundle(resource: "web/index", extension: "html", in: .module)
```

내부적으로 `Bundle.url(forResource:withExtension:)`을 호출한다. 리소스를 찾지 못하면 `ConfigurationError.resourceNotFound`를 던진다.

### file -- 로컬 파일 URL

파일 시스템 URL로 HTML을 직접 지정한다. 개발 중 소스 디렉토리를 직접 참조할 때 유용하다.

```swift
let fileURL = URL(fileURLWithPath: "/Users/dev/project/dist/index.html")
let entry = EntryPoint.file(fileURL)
```

### remote -- 원격 URL

개발 서버나 원격 배포 웹 앱에 사용한다.

```swift
let entry = EntryPoint.remote(URL(string: "http://localhost:5173")!)
```

### 계산 프로퍼티

| 메서드/프로퍼티 | 설명 |
|---------------|------|
| `resolveURL() throws -> URL` | 진입점이 가리키는 최종 URL을 반환한다. `.bundle`에서 리소스를 찾지 못하면 에러를 던진다 |
| `isLocalhost: Bool` | `.remote`이면서 호스트가 `localhost` 또는 `127.0.0.1`이면 `true` |

---

## WindowConfiguration

윈도우의 크기 및 동작을 정의하는 구조체이다.

```swift
public struct WindowConfiguration: Sendable {
    public let width: Double        // 기본값: 800
    public let height: Double       // 기본값: 600
    public let minWidth: Double?    // 기본값: nil
    public let minHeight: Double?   // 기본값: nil
    public let title: String        // 기본값: ""
    public let resizable: Bool      // 기본값: true
}
```

```swift
let window = WindowConfiguration(
    width: 1200,
    height: 800,
    minWidth: 400,
    minHeight: 300,
    title: "My Application",
    resizable: true
)
```

최소 크기를 지정하면 사용자가 윈도우를 해당 크기 이하로 줄일 수 없다.

---

## AppConfiguration

앱 전체 설정을 관리하는 구조체이다.

```swift
public struct AppConfiguration: Sendable {
    public let name: String
    public let entry: EntryPoint
    public let window: WindowConfiguration
    public let isDebug: Bool
    public let debugEntry: EntryPoint?
    public let allowedURLSchemes: [String]
    public let logLevel: LogLevel
    public let terminateOnLastWindowClose: Bool
}
```

### 초기화 파라미터

| 파라미터 | 타입 | 기본값 | 설명 |
|---------|------|--------|------|
| `name` | `String` | (필수) | 앱 이름 |
| `entry` | `EntryPoint` | (필수) | 기본 진입점 |
| `window` | `WindowConfiguration` | `WindowConfiguration()` | 윈도우 설정 |
| `debugEntry` | `EntryPoint?` | `nil` | 디버그 빌드용 대체 진입점 |
| `allowedURLSchemes` | `[String]` | `["http", "https"]` | 허용할 URL 스킴 |
| `logLevel` | `LogLevel` | `.debug` | 최소 로그 레벨 |
| `terminateOnLastWindowClose` | `Bool` | `true` | 마지막 윈도우 닫힘 시 앱 종료 여부 |

`isDebug`는 `#if DEBUG` 빌드 플래그에 의해 자동 결정된다.

### resolvedEntry

현재 빌드 모드에 따라 실제 진입점을 결정한다.

```swift
public var resolvedEntry: EntryPoint {
    isDebug ? (debugEntry ?? entry) : entry
}
```

| 빌드 모드 | 결과 |
|----------|------|
| DEBUG | `debugEntry ?? entry` |
| Release | `entry` |

### shouldWatchFiles

파일 감시(FileWatcher) 활성화 조건:
- `isDebug == true`
- `resolvedEntry`가 `.file` 케이스

### validate()

설정의 문제점을 검사하고 경고 메시지 배열을 반환한다.

```swift
let config = AppConfiguration(
    name: "App",
    entry: .remote(URL(string: "http://localhost:5173")!)
)
config.validate()
// ["entry가 localhost 개발 서버를 가리키고 있습니다."]
```

### 빌드 모드별 동작 요약

| 동작 | DEBUG | Release |
|------|-------|---------|
| `resolvedEntry`가 `debugEntry` 사용 | O (있으면) | X |
| `shouldWatchFiles` 활성화 | O (.file일 때) | X |

---

## MenuItem

플랫폼 독립적인 메뉴 구조를 정의하는 구조체이다. `LoomApplication`의 `menus` 프로퍼티에서 반환한다.

```swift
public struct MenuItem: Sendable {
    public let title: String
    public let action: (@Sendable () -> Void)?
    public let keyEquivalent: String?
    public let submenu: [MenuItem]?
    public let isSeparator: Bool
}
```

### 팩토리 메서드

```swift
// 일반 메뉴 아이템
MenuItem.item(title: "새로 만들기", key: "n") { /* 액션 */ }

// 구분선
MenuItem.separator()

// 하위 메뉴
MenuItem.submenu(title: "파일", items: [
    .item(title: "열기", key: "o") { /* 액션 */ },
    .separator(),
    .item(title: "저장", key: "s") { /* 액션 */ }
])
```

---

## 다음 단계

- [아키텍처](03-architecture.md) - 모듈 구조와 데이터 흐름
- [플러그인 시스템](04-plugin-system.md) - 플러그인 작성법
