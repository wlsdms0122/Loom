import Core
import Foundation
import Platform

/// 셸 유틸리티 플러그인. URL 열기, Finder에서 경로 열기 등의 기능을 제공한다.
public struct ShellPlugin: Plugin, Sendable {
    // MARK: - Property

    public let name = "shell"

    private let securityPolicy: any SecurityPolicy
    private let schemeWhitelist: PlatformServiceStorage<URLSchemeWhitelist>
    private let shellStorage: PlatformServiceStorage<any Shell>

    // MARK: - Initializer

    @available(*, unavailable, message: "SecurityPolicy is required. Use init(securityPolicy:) instead.")
    public init() {
        fatalError("SecurityPolicy is required")
    }

    public init(securityPolicy: any SecurityPolicy, urlSchemeWhitelist: URLSchemeWhitelist = URLSchemeWhitelist()) {
        self.securityPolicy = securityPolicy
        self.schemeWhitelist = PlatformServiceStorage(defaultValue: urlSchemeWhitelist)
        self.shellStorage = PlatformServiceStorage()
    }

    // MARK: - Public

    public func initialize(context: any PluginContext) async throws {
        if let whitelist = await context.container.resolve(URLSchemeWhitelist.self) {
            schemeWhitelist.update(whitelist)
        }
        if let shell = await context.container.resolve((any Shell).self) {
            shellStorage.update(shell)
        }
    }

    public func methods() async -> [PluginMethod] {
        let whitelist = schemeWhitelist
        let storage = shellStorage
        return [
            PluginMethod(name: "openURL") { (args: URLArgs) in
                guard let url = URL(string: args.url) else {
                    throw PluginError.invalidArguments
                }
                guard let currentWhitelist = whitelist.current else {
                    throw PluginError.invalidArguments
                }
                do {
                    try currentWhitelist.validate(url)
                } catch {
                    throw PluginError.blockedURLScheme(url.scheme ?? "none")
                }
                guard let shell = storage.current else {
                    throw PluginError.unsupportedPlatform
                }
                _ = await shell.openURL(url)
            },
            PluginMethod(name: "openPath") { [securityPolicy] (args: PathArgs) in
                do {
                    _ = try securityPolicy.validatePath(args.path)
                } catch {
                    throw PluginError.blockedPath(args.path)
                }
                guard let shell = storage.current else {
                    throw PluginError.unsupportedPlatform
                }
                _ = await shell.openPath(args.path)
            }
        ]
    }
}

// MARK: - Argument Types

/// URL 관련 인자.
private struct URLArgs: Codable, Sendable {
    let url: String
}
