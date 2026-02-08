# Loom - 제품 로드맵

> Loom은 Swift 기반 네이티브-웹 하이브리드 데스크톱 앱 프레임워크입니다.
> WKWebView와 Swift Concurrency를 활용하여 경량 macOS 데스크톱 앱을 만들 수 있습니다.

---

## 현재 기능 요약

### Core
- `Application` 프로토콜 기반 앱 생명주기 관리 (run/terminate)
- `LoomApplication` 프로토콜로 `@main` 선언적 진입점 지원
- `AppConfiguration`으로 앱 설정 (윈도우 크기/제목, 진입점, 디버그 모드, 로그 레벨)
- `EntryPoint` 열거형으로 번들 리소스 / 로컬 파일 / 원격 URL 로딩 지원
- `Container` (DI 컨테이너) — singleton/transient 스코프 지원
- `EventBus` (Actor 기반) — 타입 안전한 이벤트 발행/구독 (AsyncStream)
- `Logger` 프로토콜 및 PrintLogger/OSLogger 구현체 (4단계 로그 레벨)

### Window
- `WindowConfiguration` — 크기, 제목, 리사이즈, 타이틀바 스타일 (`visible`/`hidden`)
- 멀티 윈도우 — `LoomApp.createWindow()` 및 `additionalWindows` 설정으로 다중 윈도우 생성
- 커스텀 윈도우 크롬 — `TitlebarStyle.hidden`으로 타이틀바 숨김, 트래픽 라이트 오버레이
- 웹 기반 드래그 영역 — JS SDK `loom.window.setDragRegions()`으로 커스텀 드래그 영역 지정
- `WebEnvironment` — 타이틀바 높이 등 윈도우 정보를 CSS 커스텀 프로퍼티/JS 변수로 웹에 주입

### Plugin System
- `Plugin` 프로토콜 (name, initialize, methods, dispose)
- `PluginMethod` — JSON 문자열 핸들러 및 타입-세이프 Codable 제네릭 이니셜라이저
- `PluginRegistryActor` — Actor 기반 플러그인 등록/초기화/해제 관리 (실패 시 롤백)
- `PluginBridgeConnector` — 플러그인 메서드를 `plugin.{name}.{method}` 형식으로 Bridge에 자동 연결
- `PluginContext` — 컨테이너, 이벤트 버스, 로거, emit 기능을 플러그인에 주입
- 내장 플러그인:
  - `filesystem` — 읽기/쓰기/존재확인/목록/삭제
  - `dialog` — 파일 열기/저장 패널, 알림 대화상자
  - `clipboard` — 텍스트 읽기/쓰기
  - `shell` — URL 열기, Finder에서 경로 열기
  - `process` — 외부 프로세스 실행 (stdout/stderr 캡처, 타임아웃, 취소 지원)
  - `window` — 윈도우 드래그 제어

### Bridge & JS SDK
- `Bridge` 프로토콜 및 `BridgeActor` 구현체 — Actor 기반 양방향 비동기 통신
- `BridgeMessage` — request/response/nativeEvent/error/webEvent 5종 메시지
- `BridgeTransport` 추상화 및 `WebEngineBridgeTransport` 어댑터 (DIP 적용)
- `bridge-sdk.js` JS API:
  - `loom.invoke(method, params, options)` — 플러그인 메서드 호출 (per-call timeout 지원)
  - `loom.on(event, callback)` — 네이티브 이벤트 구독 (unsubscribe 함수 반환)
  - `loom.once(event, callback)` — 단일 발화 이벤트 구독
  - `loom.emit(event, data)` — 네이티브로 단방향 이벤트 전송
  - `loom.ready` — SDK 초기화 완료 Promise
  - `loom.setDefaultTimeout(ms)` — 기본 타임아웃 설정 (기본값 30초)
  - `loom.window.setDragRegions(regions)` / `clearDragRegions()` — 윈도우 드래그 영역 관리
- 구조화된 에러 전파 (`ErrorPayload` — code, message, plugin, method)
- 페이지 언로드 시 pending Promise 자동 정리

### Platform (macOS)
- `PlatformProvider` 프로토콜로 플랫폼별 서비스 추상화 (Abstract Factory)
- `MacOSWindowManager` — NSWindow 기반 윈도우 생성/표시/닫기, 마지막 윈도우 닫기 시 앱 종료 옵션
- `MacOSWebView` — WKWebView 래핑, 네비게이션 정책 제어
- `BundleSchemeHandler` — `loom://` 커스텀 URL 스킴으로 번들 리소스 서빙 (경로 순회 방어 포함)
- DEBUG 모드에서 WebKit Inspector 활성화 및 JS console 로그 Swift Logger 포워딩
- `MacOSMenuBuilder` — MenuItem 모델로 NSMenu 생성 (서브메뉴, 키보드 단축키, 표준 편집 액션)
- `MacOSStatusItem` — NSStatusItem 기반 메뉴바 상태 아이템
- `MacOSFileWatcher` — FSEvents 기반 파일 변경 감시 (개발 모드 자동 리로드)
- macOS 전용 서비스: FileSystem, Dialogs (NSOpenPanel/NSSavePanel/NSAlert), Clipboard, Shell

### Security
- `SecurityPolicy` 프로토콜 및 `PathSandbox` 구현체 — 심볼릭 링크 해석 포함 경로 검증
- `URLSchemeWhitelist` — 허용된 URL 스킴만 통과
- `BundleSchemeHandler` — 경로 순회(path traversal) 방어
- filesystem/shell/process 플러그인에 SecurityPolicy 필수 적용

### Development
- Swift 6.0 Strict Concurrency — Actor 기반 data race 방지
- SPM 기반 모듈 분리 (Core, Bridge, Platform, PlatformMacOS, Plugin, WebEngine, Loom)
- 모든 모듈에 대한 테스트 타겟 구성 (`LoomTestKit` 공용 테스트 유틸리티)

---

## 로드맵

### Phase 2: 데스크톱 앱 필수 기능
- 윈도우 간 통신 (이벤트 버스 또는 메시지 채널 기반)
- 글로벌/로컬 키보드 단축키 등록
- macOS 네이티브 알림 (UserNotifications)
- npm 패키지 (`@aspect/loom-api`) — TypeScript 타입 정의 및 플러그인별 래퍼 함수

### Phase 3: 개발 도구 및 배포
- CLI 도구 (`loom create`, `loom dev`, `loom build`)
- 앱 번들링 (.app), 코드 서명, 공증 (Notarization)
- 투명 배경 윈도우
- Sparkle 기반 자동 업데이트
- 플러그인 레지스트리/저장소

### Phase 4: 크로스 플랫폼
- Windows 지원 (WinUI WebView2)
- Linux 지원 (WebKitGTK)
- 플러그인별 프로세스 샌드박싱
- 메인 윈도우 없는 백그라운드 서비스
