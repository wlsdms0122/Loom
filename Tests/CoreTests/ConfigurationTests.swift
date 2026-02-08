import Foundation
import Testing
@testable import Core

/// AppConfiguration, EntryPoint, WindowConfiguration을 검증한다.
@Suite("Configuration")
struct ConfigurationTests {
    // MARK: - AppConfiguration Init
    @Test("AppConfiguration이 주어진 값으로 초기화된다")
    func appConfigurationInit() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html")),
            window: WindowConfiguration(
                width: 1024,
                height: 768,
                title: "Test"
            )
        )

        #expect(config.name == "TestApp")
        #expect(config.window.width == 1024)
        #expect(config.window.height == 768)
        #expect(config.window.title == "Test")
    }

    @Test("AppConfiguration이 isDebug를 자동 감지한다")
    func appConfigurationAutoDetectedDebug() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html"))
        )

        // 테스트는 DEBUG 빌드에서 실행되므로 isDebug == true
        #expect(config.isDebug == true)
    }

    @Test("AppConfiguration이 명시적 isDebug 주입으로 초기화된다")
    func appConfigurationExplicitIsDebug() {
        let debugConfig = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html")),
            isDebug: true
        )
        #expect(debugConfig.isDebug == true)

        let releaseConfig = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html")),
            isDebug: false
        )
        #expect(releaseConfig.isDebug == false)
    }

    @Test("debugEntry 기본값이 nil이다")
    func debugEntryDefaultIsNil() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html"))
        )

        #expect(config.debugEntry == nil)
    }

    // MARK: - resolvedEntry
    @Test("디버그 모드에서 debugEntry가 있으면 debugEntry를 반환한다")
    func resolvedEntryDebugWithDebugEntry() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/dist/index.html")),
            debugEntry: .file(URL(fileURLWithPath: "/src/index.html")),
            isDebug: true
        )

        #expect(config.resolvedEntry == .file(URL(fileURLWithPath: "/src/index.html")))
    }

    @Test("디버그 모드에서 debugEntry가 없으면 entry로 폴백한다")
    func resolvedEntryDebugWithoutDebugEntry() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/dist/index.html")),
            isDebug: true
        )

        #expect(config.resolvedEntry == .file(URL(fileURLWithPath: "/dist/index.html")))
    }

    @Test("릴리스 모드에서 debugEntry를 무시한다")
    func resolvedEntryReleaseIgnoresDebugEntry() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/dist/index.html")),
            debugEntry: .file(URL(fileURLWithPath: "/src/index.html")),
            isDebug: false
        )

        #expect(config.resolvedEntry == .file(URL(fileURLWithPath: "/dist/index.html")))
    }

    // MARK: - shouldWatchFiles
    @Test("디버그 모드 + 파일 진입점이면 shouldWatchFiles가 true이다")
    func shouldWatchFilesDebugFile() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html")),
            isDebug: true
        )

        #expect(config.shouldWatchFiles == true)
    }

    @Test("디버그 모드 + 원격 진입점이면 shouldWatchFiles가 false이다")
    func shouldWatchFilesDebugRemote() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/dist/index.html")),
            debugEntry: .remote(URL(string: "http://localhost:5173")!),
            isDebug: true
        )

        #expect(config.shouldWatchFiles == false)
    }

    @Test("릴리스 모드이면 shouldWatchFiles가 false이다")
    func shouldWatchFilesRelease() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html")),
            isDebug: false
        )

        #expect(config.shouldWatchFiles == false)
    }

    // MARK: - validate
    @Test("entry가 localhost를 가리키면 경고를 반환한다")
    func validateWarnsLocalhostEntry() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .remote(URL(string: "http://localhost:5173")!),
            isDebug: false
        )

        let warnings = config.validate()
        #expect(warnings.count >= 1)
        #expect(warnings.contains { $0.contains("localhost") })
    }

    @Test("안전한 설정이면 validate가 빈 배열을 반환한다")
    func validateReturnsEmptyForSafeConfig() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/dist/index.html")),
            isDebug: false
        )

        #expect(config.validate().isEmpty)
    }

    @Test("원격 프로덕션 URL은 validate가 빈 배열을 반환한다")
    func validateReturnsEmptyForRemoteProduction() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .remote(URL(string: "https://app.example.com")!),
            isDebug: false
        )

        #expect(config.validate().isEmpty)
    }

    // MARK: - EntryPoint resolveURL
    @Test("EntryPoint.file이 올바른 URL을 반환한다")
    func entryPointFileURL() throws {
        let fileURL = URL(fileURLWithPath: "/app/index.html")
        let entry = EntryPoint.file(fileURL)

        #expect(try entry.resolveURL() == fileURL)
    }

    @Test("EntryPoint.remote가 올바른 URL을 반환한다")
    func entryPointRemoteURL() throws {
        let remoteURL = URL(string: "https://example.com")!
        let entry = EntryPoint.remote(remoteURL)

        #expect(try entry.resolveURL() == remoteURL)
    }

    @Test("EntryPoint.bundle에서 리소스를 찾을 수 없으면 ConfigurationError를 던진다")
    func entryPointBundleThrowsOnMissingResource() {
        let entry = EntryPoint.bundle(resource: "nonexistent", extension: "html", in: .main)

        #expect(throws: ConfigurationError.self) {
            try entry.resolveURL()
        }
    }

    // MARK: - EntryPoint resolveLoadURL
    @Test("EntryPoint.file이 resolveLoadURL에서 올바른 URL을 반환한다")
    func entryPointFileResolveLoadURL() throws {
        let fileURL = URL(fileURLWithPath: "/app/index.html")
        let entry = EntryPoint.file(fileURL)

        #expect(try entry.resolveLoadURL() == fileURL)
    }

    @Test("EntryPoint.remote가 resolveLoadURL에서 올바른 URL을 반환한다")
    func entryPointRemoteResolveLoadURL() throws {
        let remoteURL = URL(string: "https://example.com")!
        let entry = EntryPoint.remote(remoteURL)

        #expect(try entry.resolveLoadURL() == remoteURL)
    }

    @Test("EntryPoint.bundle이 resolveLoadURL에서 loom:// 스킴 URL을 반환한다")
    func entryPointBundleResolveLoadURLThrowsOnMissingResource() {
        let entry = EntryPoint.bundle(resource: "nonexistent", extension: "html", in: .main)

        #expect(throws: ConfigurationError.self) {
            try entry.resolveLoadURL()
        }
    }

    // MARK: - EntryPoint isLocalhost
    @Test("EntryPoint.isLocalhost가 localhost URL에 대해 true를 반환한다")
    func entryPointIsLocalhost() {
        #expect(EntryPoint.remote(URL(string: "http://localhost:5173")!).isLocalhost == true)
        #expect(EntryPoint.remote(URL(string: "http://127.0.0.1:3000")!).isLocalhost == true)
        #expect(EntryPoint.remote(URL(string: "https://example.com")!).isLocalhost == false)
        #expect(EntryPoint.file(URL(fileURLWithPath: "/index.html")).isLocalhost == false)
    }

    // MARK: - EntryPoint Equatable
    @Test("EntryPoint.file이 동일한 URL에 대해 Equatable을 만족한다")
    func entryPointFileEquatable() {
        let url = URL(fileURLWithPath: "/app/index.html")
        #expect(EntryPoint.file(url) == EntryPoint.file(url))
    }

    @Test("EntryPoint.remote가 동일한 URL에 대해 Equatable을 만족한다")
    func entryPointRemoteEquatable() {
        let url = URL(string: "https://example.com")!
        #expect(EntryPoint.remote(url) == EntryPoint.remote(url))
    }

    @Test("EntryPoint.bundle이 동일한 파라미터에 대해 Equatable을 만족한다")
    func entryPointBundleEquatable() {
        let entry1 = EntryPoint.bundle(resource: "index", extension: "html", in: .main)
        let entry2 = EntryPoint.bundle(resource: "index", extension: "html", in: .main)
        #expect(entry1 == entry2)
    }

    @Test("서로 다른 EntryPoint 케이스는 Equatable을 만족하지 않는다")
    func entryPointDifferentCasesNotEqual() {
        let fileEntry = EntryPoint.file(URL(fileURLWithPath: "/index.html"))
        let remoteEntry = EntryPoint.remote(URL(string: "https://example.com")!)
        #expect(fileEntry != remoteEntry)
    }

    // MARK: - terminateOnLastWindowClose
    @Test("terminateOnLastWindowClose 기본값이 true이다")
    func terminateOnLastWindowCloseDefaultTrue() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html"))
        )

        #expect(config.terminateOnLastWindowClose == true)
    }

    @Test("terminateOnLastWindowClose를 false로 설정할 수 있다")
    func terminateOnLastWindowCloseSetFalse() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html")),
            terminateOnLastWindowClose: false
        )

        #expect(config.terminateOnLastWindowClose == false)
    }

    @Test("terminateOnLastWindowClose를 true로 명시적 설정할 수 있다")
    func terminateOnLastWindowCloseSetTrue() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/index.html")),
            terminateOnLastWindowClose: true
        )

        #expect(config.terminateOnLastWindowClose == true)
    }

    @Test("terminateOnLastWindowClose가 다른 설정과 함께 올바르게 저장된다")
    func terminateOnLastWindowCloseWithOtherSettings() {
        let config = AppConfiguration(
            name: "TestApp",
            entry: .file(URL(fileURLWithPath: "/dist/index.html")),
            window: WindowConfiguration(width: 1024, height: 768, title: "Test"),
            debugEntry: .remote(URL(string: "http://localhost:5173")!),
            terminateOnLastWindowClose: false,
            isDebug: true
        )

        #expect(config.terminateOnLastWindowClose == false)
        #expect(config.name == "TestApp")
        #expect(config.window.width == 1024)
        #expect(config.isDebug == true)
    }

    // MARK: - WindowConfiguration
    @Test("WindowConfiguration 기본값이 올바르다")
    func windowConfigurationDefaults() {
        let config = WindowConfiguration()

        #expect(config.width == 800)
        #expect(config.height == 600)
        #expect(config.minWidth == nil)
        #expect(config.minHeight == nil)
        #expect(config.title == "")
        #expect(config.resizable == true)
        #expect(config.titlebarStyle == .visible)
    }

    @Test("WindowConfiguration이 모든 커스텀 값을 올바르게 저장한다")
    func windowConfigurationCustomValues() {
        let config = WindowConfiguration(
            width: 1920,
            height: 1080,
            minWidth: 640,
            minHeight: 480,
            title: "Custom Window",
            resizable: false
        )

        #expect(config.width == 1920)
        #expect(config.height == 1080)
        #expect(config.minWidth == 640)
        #expect(config.minHeight == 480)
        #expect(config.title == "Custom Window")
        #expect(config.resizable == false)
    }

    // MARK: - TitlebarStyle
    @Test("WindowConfiguration의 기본 titlebarStyle은 .visible이다")
    func defaultTitlebarStyle() {
        let config = WindowConfiguration()
        #expect(config.titlebarStyle == .visible)
    }

    @Test("WindowConfiguration에 titlebarStyle을 지정할 수 있다")
    func customTitlebarStyle() {
        let config = WindowConfiguration(titlebarStyle: .hidden)
        #expect(config.titlebarStyle == .hidden)
    }
}
