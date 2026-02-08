# 빌드 및 명령어

빌드, 테스트, 실행 명령어 요약.

---

## 프레임워크 빌드

| 명령어 | 설명 |
|-------|------|
| `swift build` | 프레임워크 빌드 (DEBUG) |
| `swift build -c release` | 프레임워크 릴리스 빌드 |

### 빌드 모드별 동작

- `swift build` -- `isDebug == true`, `debugEntry` 사용, FileWatcher 활성화 가능
- `swift build -c release` -- `isDebug == false`, `entry`만 사용, FileWatcher 비활성화

---

## 테스트

| 명령어 | 설명 |
|-------|------|
| `swift test` | 전체 테스트 실행 |
| `swift test --filter CoreTests` | Core 모듈 테스트 |
| `swift test --filter BridgeTests` | Bridge 모듈 테스트 |
| `swift test --filter PlatformTests` | Platform 모듈 테스트 |
| `swift test --filter PluginTests` | Plugin 모듈 테스트 |
| `swift test --filter WebEngineTests` | WebEngine 모듈 테스트 |
| `swift test --filter LoomTests` | Loom 통합 테스트 |

---

## 샘플 앱

| 명령어 | 설명 |
|-------|------|
| `swift build --package-path sample` | 샘플 앱 빌드 |
| `swift run --package-path sample LoomSample` | 샘플 앱 실행 |
| `swift test --package-path sample` | 샘플 앱 테스트 실행 |

---

## 웹 프론트엔드 (개발 서버 사용 시)

```bash
cd frontend
npm install
npm run dev      # 개발 서버 시작 (예: http://localhost:5173)
npm run build    # 프로덕션 빌드 -> dist/
```

---

## 전체 개발 워크플로우

1. 프론트엔드 개발 서버를 시작한다:
   ```bash
   cd frontend && npm run dev
   ```

2. 별도 터미널에서 Loom 앱을 실행한다:
   ```bash
   swift run --package-path sample LoomSample
   ```

3. 프론트엔드 코드를 수정하면 HMR이 자동으로 반영한다.

4. 배포 시에는 프론트엔드를 빌드하고 릴리스 빌드를 생성한다:
   ```bash
   cd frontend && npm run build
   swift build -c release
   ```

---

## 빌드 안전성

릴리스 빌드에서 개발 서버 URL이 포함되는 실수를 방지하기 위해 `validate()`가 경고를 출력한다.

### 올바른 설정 패턴

```swift
let config = AppConfiguration(
    name: "My App",
    entry: .bundle(resource: "web/index", extension: "html", in: .module),
    debugEntry: .remote(URL(string: "http://localhost:5173")!)
)
config.validate()  // [] -- 경고 없음
```

### 흔한 실수

| 실수 | 문제 | 해결 |
|------|------|------|
| `entry`에 localhost URL | 릴리스에서 localhost 로드 시도 | `entry`에 번들 리소스, `debugEntry`에 개발 서버 |
| `debugEntry` 미설정 | 개발 중 빌드 산출물만 로드 | `debugEntry`를 별도 설정 |

---

## 다음 단계

- [개요](00-overview.md) - Loom 프레임워크 소개로 돌아가기
- [시작하기](01-getting-started.md) - 프로젝트 시작 가이드
