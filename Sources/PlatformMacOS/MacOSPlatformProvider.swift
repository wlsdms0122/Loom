import AppKit
import Foundation
import WebKit
import Core
import Platform

/// macOS 플랫폼 제공자 구현체.
// 안전성: @unchecked Sendable — 이 타입은 @MainActor로 격리되어 있다.
// 모든 접근이 메인 스레드에서 직렬화된다.
@MainActor
public final class MacOSPlatformProvider: PlatformProvider, @unchecked Sendable {
    // MARK: - Property
    public nonisolated let system: SystemInfo

    // MARK: - Initializer
    public init() {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        self.system = SystemInfo(
            osName: "macOS",
            osVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            architecture: {
                #if arch(arm64)
                return "arm64"
                #else
                return "x86_64"
                #endif
            }()
        )
    }

    // MARK: - Public
    public func makeWindowManager() -> any WindowManager {
        MacOSWindowManager()
    }

    public func makeWebView(configuration: WindowConfiguration) -> any NativeWebView {
        MacOSWebView(configuration: configuration)
    }

    public func makeWebView(configuration: WindowConfiguration, entry: EntryPoint) -> any NativeWebView {
        if case .bundle(_, _, let bundle) = entry {
            let schemeHandler = BundleSchemeHandler(bundle: bundle)
            return MacOSWebView(
                configuration: configuration,
                schemeHandlers: [("loom", schemeHandler)]
            )
        }
        return MacOSWebView(configuration: configuration)
    }

    public func makeFileSystem() -> any FileSystem {
        MacOSFileSystem()
    }

    public func makeDialogs() -> any SystemDialogs {
        MacOSDialogs()
    }

    public func makeClipboard() -> any Clipboard {
        MacOSClipboard()
    }

    public func makeShell() -> any Shell {
        MacOSShell()
    }

    public func applyMenu(_ items: [MenuItem]) -> AnyObject? {
        let menuBuilder = MacOSMenuBuilder()
        let mainMenu = menuBuilder.build(from: items)
        NSApplication.shared.mainMenu = mainMenu
        return menuBuilder
    }

    public func makeFileWatcher() -> (any FileWatcher)? {
        MacOSFileWatcher()
    }

    public func makeStatusItem() -> (any StatusItem)? {
        MacOSStatusItem()
    }
}
