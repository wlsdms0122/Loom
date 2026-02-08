import AppKit
import Core
import Platform
import Plugin

/// Loom 애플리케이션의 선언적 진입점.
/// 이 프로토콜을 채택하고 `@main`을 붙여 최소한의 보일러플레이트로 Loom 앱을 생성한다.
///
/// 예시:
/// ```swift
/// @main
/// struct MyApp: LoomApplication {
///     var configuration: AppConfiguration { ... }
///     var plugins: [any Plugin] { [] }
/// }
/// ```
public protocol LoomApplication {
    // MARK: - Property

    /// 진입점, 윈도우, 디버그 설정을 기술하는 앱 설정.
    var configuration: AppConfiguration { get }

    /// Loom 런타임에 등록할 플러그인 목록.
    var plugins: [any Plugin] { get }

    /// 추가 윈도우 설정 목록. 기본값은 빈 배열이다.
    var additionalWindows: [WindowConfiguration] { get }

    /// 앱 메뉴 항목 목록. 기본값은 빈 배열이다.
    var menus: [MenuItem] { get }

    /// 앱에서 사용할 로거. 기본값은 `PrintLogger(minLevel: configuration.logLevel)`이다.
    var logger: any Logger { get }

    // MARK: - Initializer

    /// `@main` 지원을 위한 기본 빈 이니셜라이저 요구사항.
    init()

    // MARK: - Public

    /// Swift 런타임에서 호출되는 진입점. 기본 구현이 제공된다.
    @MainActor static func main()
}

// MARK: - Default Implementation

extension LoomApplication {
    /// 추가 윈도우 기본값은 빈 배열이다.
    public var additionalWindows: [WindowConfiguration] { [] }

    /// 앱 메뉴 기본값은 빈 배열이다.
    public var menus: [MenuItem] { [] }

    /// 기본 로거는 `PrintLogger`이며, 설정의 로그 레벨을 사용한다.
    public var logger: any Logger {
        PrintLogger(minLevel: configuration.logLevel)
    }

    /// NSApplication을 설정하고, LoomApp을 생성하며, 이벤트 루프를 실행하는 기본 구현.
    ///
    /// 동기 진입점을 사용하여 NSApplication.run() 이벤트 루프와
    /// Swift 동시성 런타임 간의 충돌을 방지한다.
    @MainActor
    public static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let instance = Self()
        let loomApp = LoomApp(
            configuration: instance.configuration,
            logger: instance.logger,
            plugins: instance.plugins,
            additionalWindows: instance.additionalWindows,
            menus: instance.menus
        )

        Task { @MainActor in
            do {
                try await loomApp.run()
            } catch {
                NSLog("[Loom] Error: \(error)")
                app.terminate(nil)
            }
        }

        app.activate()
        app.run()
    }
}
