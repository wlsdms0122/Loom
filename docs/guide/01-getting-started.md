# 시작하기

Loom 프로젝트 생성부터 Hello World 실행까지.

---

## 최소 요구사항

- macOS 14 (Sonoma) 이상
- Swift 6.0 이상
- Xcode 16.0 이상

---

## Package.swift 설정

프로젝트의 `Package.swift`에 Loom 의존성을 추가한다.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/aspect/Loom.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "Loom", package: "Loom"),
                .product(name: "LoomCore", package: "Loom"),
                .product(name: "LoomPlugin", package: "Loom")
            ],
            resources: [.copy("Resources/web")]
        )
    ]
)
```

### 사용 가능한 제품 모듈

| 제품 이름 | 설명 |
|----------|------|
| `Loom` | 전체 통합 모듈 (일반적으로 이것을 사용) |
| `LoomCore` | Configuration, Container, EventBus 등 핵심 타입 |
| `LoomBridge` | JS/Swift 간 통신 브릿지 |
| `LoomPlatform` | 플랫폼 추상화 프로토콜 |
| `LoomPlugin` | 플러그인 시스템 |
| `LoomWebEngine` | 웹 렌더링 엔진 추상화 |

---

## Hello World

가장 간단한 Loom 앱은 `LoomApplication` 프로토콜에 `@main`을 붙여 작성한다.

```swift
import Core
import Loom
import Plugin

@main
struct HelloWorld: LoomApplication {
    var configuration: AppConfiguration {
        AppConfiguration(
            name: "Hello",
            entry: .bundle(resource: "index", extension: "html"),
            window: WindowConfiguration(title: "Hello World")
        )
    }

    var plugins: [any Plugin] { [] }
}
```

이 코드만으로 네이티브 macOS 윈도우가 생성되고, 번들에 포함된 `index.html`이 WKWebView에 로드된다.

---

## 기본 앱 구조

### 선언적 방식 (권장)

`LoomApplication` 프로토콜을 채택하면 `NSApplication` 설정 보일러플레이트 없이 앱을 작성할 수 있다.

```swift
import Core
import Loom
import Plugin

@main
struct MyApp: LoomApplication {
    var configuration: AppConfiguration {
        AppConfiguration(
            name: "My App",
            entry: .bundle(resource: "web/index", extension: "html", in: .module),
            window: WindowConfiguration(
                width: 1000,
                height: 700,
                title: "My App",
                resizable: true
            )
        )
    }

    var plugins: [any Plugin] {
        [
            FileSystemPlugin(securityPolicy: PathSandbox(allowedDirectories: ["/tmp"])),
            DialogPlugin(),
            ClipboardPlugin(),
            ShellPlugin(securityPolicy: PathSandbox(allowedDirectories: ["/tmp"]))
        ]
    }
}
```

`LoomApplication`의 기본 `main()` 구현이 내부적으로 다음을 수행한다:

1. `NSApplication.shared`를 설정한다.
2. `LoomApp` 인스턴스를 생성하여 `run()`을 호출한다.
3. `NSApplication`의 이벤트 루프를 시작한다.

### 명령형 방식 (대안)

더 세밀한 제어가 필요하면 `LoomApp`을 직접 생성하여 실행할 수 있다.

```swift
import AppKit
import Core
import Loom
import Plugin

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let configuration = AppConfiguration(
    name: "My App",
    entry: .bundle(resource: "web/index", extension: "html", in: .module),
    window: WindowConfiguration(
        width: 1000,
        height: 700,
        title: "My App",
        resizable: true
    )
)

let loomApp = LoomApp(
    configuration: configuration,
    plugins: [
        DialogPlugin(),
        ClipboardPlugin()
    ]
)

Task {
    do {
        try await loomApp.run()
    } catch {
        NSLog("Loom error: \(error)")
    }
}

app.activate()
app.run()
```

---

## 다음 단계

- [설정](02-configuration.md) - AppConfiguration 상세 옵션
- [플러그인 시스템](04-plugin-system.md) - 커스텀 플러그인 작성
