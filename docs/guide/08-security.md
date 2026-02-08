# 보안

SecurityPolicy 프로토콜, PathSandbox, URLSchemeWhitelist, 보안 모범 사례.

---

## SecurityPolicy 프로토콜

경로와 URL을 검증하는 보안 정책의 추상화이다.

```swift
public protocol SecurityPolicy: Sendable {
    func validatePath(_ path: String) throws -> URL
    func validateURL(_ url: URL) throws
}
```

`FileSystemPlugin`, `ShellPlugin`, `ProcessPlugin`은 생성 시 `SecurityPolicy`를 필수로 요구한다. 이를 통해 플러그인이 접근할 수 있는 파일 경로와 URL을 제한한다.

---

## PathSandbox

허용된 디렉토리로 파일 시스템 접근을 제한하는 `SecurityPolicy` 구현체이다.

```swift
public struct PathSandbox: SecurityPolicy, Sendable {
    public init(
        allowedDirectories: [String],
        allowedSchemes: Set<String> = ["http", "https"]
    )

    public func validatePath(_ path: String) throws -> URL
    public func validateURL(_ url: URL) throws
}
```

### 동작 방식

1. 경로의 `~`를 홈 디렉토리로 확장한다
2. `realpath`로 심볼릭 링크를 해석한다 (파일이 없으면 상위 디렉토리를 해석)
3. 해석된 경로가 허용 디렉토리 중 하나로 시작하는지 검증한다
4. 위반 시 `SandboxError.pathNotAllowed`를 던진다

### 사용 예시

```swift
let sandbox = PathSandbox(
    allowedDirectories: ["/tmp", "/Users/me/projects"],
    allowedSchemes: ["http", "https"]
)

// 허용된 경로
let url = try sandbox.validatePath("/tmp/data.txt")  // OK

// 허용되지 않은 경로
try sandbox.validatePath("/etc/passwd")  // throws SandboxError.pathNotAllowed
```

### 에러 타입

```swift
public enum SandboxError: Error, Sendable, Equatable {
    case pathNotAllowed(String)     // 허용 디렉토리 밖의 경로
    case schemeNotAllowed(String)   // 허용되지 않은 URL 스킴
    case invalidPath(String)        // 경로 해석 불가
}
```

---

## URLSchemeWhitelist

허용된 URL 스킴만 통과시키는 검증기이다. `ShellPlugin`의 `openURL`에서 사용된다.

```swift
public struct URLSchemeWhitelist: Sendable {
    public init(schemes: [String] = ["http", "https"])
    public func validate(_ url: URL) throws
}
```

```swift
let whitelist = URLSchemeWhitelist(schemes: ["http", "https"])

try whitelist.validate(URL(string: "https://github.com")!)  // OK
try whitelist.validate(URL(string: "file:///etc/passwd")!)   // throws WhitelistError
```

### 에러 타입

```swift
public enum WhitelistError: Error, Sendable, Equatable {
    case schemeNotAllowed(String)
}
```

---

## 보안 모범 사례

### 최소 권한 원칙

허용 디렉토리를 앱이 실제로 필요한 최소 범위로 제한한다.

```swift
// 나쁜 예: 홈 디렉토리 전체 허용
PathSandbox(allowedDirectories: ["/Users/me"])

// 좋은 예: 필요한 디렉토리만 허용
PathSandbox(allowedDirectories: ["/Users/me/projects/myapp/data"])
```

### ProcessPlugin 주의사항

`ProcessPlugin`은 외부 프로세스를 실행할 수 있으므로 허용 디렉토리를 신중하게 설정해야 한다.

```swift
// 시스템 바이너리만 허용
ProcessPlugin(securityPolicy: PathSandbox(allowedDirectories: ["/usr/bin"]))
```

### URL 스킴 제한

`AppConfiguration`의 `allowedURLSchemes`와 `ShellPlugin`의 `URLSchemeWhitelist`를 활용하여 허용 스킴을 제한한다.

```swift
AppConfiguration(
    name: "My App",
    entry: .bundle(resource: "index", extension: "html"),
    allowedURLSchemes: ["http", "https"]
)
```

---

## 다음 단계

- [내장 플러그인](05-builtin-plugins.md) - SecurityPolicy가 필요한 플러그인
- [개발 환경](09-development.md) - 개발 시 디버깅과 보안 설정
