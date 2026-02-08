# Loom 개요

Swift 6.0 기반의 경량 하이브리드 데스크톱 애플리케이션 프레임워크.

---

## Loom이란?

Loom은 macOS 네이티브 WKWebView를 활용하여 웹 기술(HTML/CSS/JavaScript)로 UI를 구성하고, Swift로 백엔드 로직을 작성하는 하이브리드 데스크톱 프레임워크이다.

### 비전

- Chromium 번들 없이 OS 내장 WebView만으로 경량 데스크톱 앱 제작
- Swift의 강력한 타입 시스템과 동시성 모델을 백엔드에 활용
- 플러그인 아키텍처를 통해 네이티브 기능을 웹에 자유롭게 노출

### 대상 플랫폼

- macOS 14 (Sonoma) 이상

---

## 핵심 특징

- **Swift 네이티브 백엔드**: AppKit, Foundation 등 macOS 시스템 프레임워크에 직접 접근
- **OS 내장 WebView 활용**: WKWebView를 사용하여 앱 크기가 작음 (목표 3-10MB)
- **Swift 6.0 동시성**: Actor 모델과 async/await 기반의 안전한 동시성 처리
- **플러그인 아키텍처**: 네이티브 기능을 모듈화하여 JavaScript에 노출하는 확장 시스템
- **양방향 브릿지**: JavaScript와 Swift 간 Promise 기반의 비동기 통신
- **외부 의존성 없음**: Swift Package Manager만으로 빌드
- **프론트엔드 자유도**: React, Vue, Svelte 등 어떤 웹 프레임워크든 사용 가능

---

## 경쟁 프레임워크와 비교

| 항목 | Electron | Tauri | Loom |
|------|----------|-------|------|
| 백엔드 언어 | Node.js | Rust | Swift |
| 렌더링 엔진 | Chromium (번들) | OS WebView | OS WebView (WKWebView) |
| 앱 바이너리 크기 | ~150MB+ | ~3-10MB | ~3-10MB |
| 메모리 사용량 | 높음 | 낮음 | 낮음 |
| macOS 통합도 | 보통 | 보통 | 높음 (네이티브 Swift) |
| 빌드 시스템 | npm | Cargo | Swift Package Manager |
| 동시성 모델 | Event Loop | Tokio async/await | Swift Concurrency (async/await, Actor) |

Electron은 Chromium을 번들하여 크로스 플랫폼을 지원하지만 앱 크기와 메모리 사용량이 크다. Tauri는 OS WebView를 활용하여 경량이지만 Rust 백엔드를 사용한다. Loom은 Swift 네이티브 생태계와의 통합에 최적화되어 있다.

---

## 다음 단계

- [시작하기](01-getting-started.md) - Hello World부터 시작
- [아키텍처](03-architecture.md) - 모듈 구조와 데이터 흐름 이해
