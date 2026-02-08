import Testing
import Foundation
@testable import Core
import Plugin
@testable import Loom
import LoomTestKit

/// LoomApplication 프로토콜의 선언적 설정이 올바르게 동작하는지 검증한다.
@Suite("LoomApplication 프로토콜 테스트")
struct LoomApplicationTests {
    // MARK: - Test Types

    /// 테스트용 LoomApplication 구현. 설정과 플러그인을 제공한다.
    struct TestApp: LoomApplication {
        var configuration: AppConfiguration {
            AppConfiguration(
                name: "TestDeclarativeApp",
                entry: .file(URL(fileURLWithPath: "/tmp/test/index.html")),
                window: WindowConfiguration(
                    width: 1200,
                    height: 800,
                    title: "Test Window"
                )
            )
        }

        var plugins: [any Plugin] {
            [MockPlugin(name: "testPlugin")]
        }
    }

    /// 플러그인이 없는 최소 LoomApplication 구현.
    struct MinimalApp: LoomApplication {
        var configuration: AppConfiguration {
            AppConfiguration(
                name: "MinimalApp",
                entry: .file(URL(fileURLWithPath: "/tmp/minimal/index.html"))
            )
        }

        var plugins: [any Plugin] { [] }
    }

    // MARK: - Tests

    @Test("LoomApplication 구현체의 configuration이 올바른 값을 반환한다")
    func configurationReturnsCorrectValues() {
        let app = TestApp()

        #expect(app.configuration.name == "TestDeclarativeApp")
        #expect(app.configuration.window.width == 1200)
        #expect(app.configuration.window.height == 800)
        #expect(app.configuration.window.title == "Test Window")
    }

    @Test("LoomApplication 구현체의 plugins가 올바른 플러그인을 반환한다")
    func pluginsReturnsCorrectPlugins() {
        let app = TestApp()

        #expect(app.plugins.count == 1)
        #expect(app.plugins.first?.name == "testPlugin")
    }

    @Test("LoomApplication에서 생성한 LoomApp이 올바른 설정을 가진다")
    func loomAppCreatedFromProtocolHasCorrectConfiguration() {
        let instance = TestApp()
        let loomApp = LoomApp(
            configuration: instance.configuration,
            plugins: instance.plugins
        )

        #expect(loomApp.configuration.name == "TestDeclarativeApp")
        #expect(loomApp.configuration.window.width == 1200)
        #expect(loomApp.configuration.window.height == 800)
        #expect(loomApp.configuration.window.title == "Test Window")
        #expect(loomApp.id == "TestDeclarativeApp")
    }

    @Test("플러그인 없는 최소 LoomApplication이 올바르게 동작한다")
    func minimalAppWithNoPlugins() {
        let instance = MinimalApp()
        let loomApp = LoomApp(
            configuration: instance.configuration,
            plugins: instance.plugins
        )

        #expect(loomApp.configuration.name == "MinimalApp")
        #expect(loomApp.id == "MinimalApp")
    }

    @Test("LoomApplication의 기본 init()으로 인스턴스를 생성할 수 있다")
    func defaultInitCreatesInstance() {
        let app = TestApp()
        #expect(app.configuration.name == "TestDeclarativeApp")
    }

    @Test("기존 imperative LoomApp API가 여전히 동작한다")
    func imperativeAPIStillWorks() {
        let config = AppConfiguration(
            name: "ImperativeApp",
            entry: .file(URL(fileURLWithPath: "/tmp/imperative/index.html")),
            window: WindowConfiguration(width: 800, height: 600, title: "Imperative"),
            isDebug: false
        )
        let plugin = MockPlugin(name: "imperativePlugin")
        let app = LoomApp(configuration: config, plugins: [plugin])

        #expect(app.id == "ImperativeApp")
        #expect(app.configuration.name == "ImperativeApp")
        #expect(app.configuration.window.title == "Imperative")
    }

    @Test("LoomApplication 구현체에서 여러 플러그인을 등록할 수 있다")
    func multiplePluginsFromDeclarativeApp() {
        struct MultiPluginApp: LoomApplication {
            var configuration: AppConfiguration {
                AppConfiguration(
                    name: "MultiPlugin",
                    entry: .file(URL(fileURLWithPath: "/tmp/multi/index.html"))
                )
            }

            var plugins: [any Plugin] {
                [
                    MockPlugin(name: "alpha"),
                    MockPlugin(name: "beta"),
                    MockPlugin(name: "gamma")
                ]
            }
        }

        let instance = MultiPluginApp()
        let loomApp = LoomApp(
            configuration: instance.configuration,
            plugins: instance.plugins
        )

        #expect(loomApp.configuration.name == "MultiPlugin")
        #expect(instance.plugins.count == 3)
        #expect(instance.plugins.map(\.name) == ["alpha", "beta", "gamma"])
    }
}
