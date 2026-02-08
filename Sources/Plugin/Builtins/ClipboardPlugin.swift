import Foundation
import Platform

/// 클립보드 플러그인. 텍스트 읽기/쓰기 기능을 제공한다.
public struct ClipboardPlugin: Plugin, Sendable {
    // MARK: - Property

    public let name = "clipboard"
    private let clipboardStorage: PlatformServiceStorage<any Clipboard>

    // MARK: - Initializer

    public init() {
        self.clipboardStorage = PlatformServiceStorage()
    }

    // MARK: - Public

    public func initialize(context: any PluginContext) async throws {
        if let clipboard = await context.container.resolve((any Clipboard).self) {
            clipboardStorage.update(clipboard)
        }
    }

    public func methods() async -> [PluginMethod] {
        let storage = clipboardStorage
        return [
            PluginMethod(name: "readText") { () -> [String: String] in
                guard let clipboard = storage.current else {
                    throw PluginError.unsupportedPlatform
                }
                let text = await clipboard.readText() ?? ""
                return ["text": text]
            },
            PluginMethod(name: "writeText") { (args: ClipboardWriteArgs) in
                guard let clipboard = storage.current else {
                    throw PluginError.unsupportedPlatform
                }
                _ = await clipboard.writeText(args.text)
            }
        ]
    }
}

// MARK: - Argument Types

/// 클립보드 텍스트 쓰기 인자.
private struct ClipboardWriteArgs: Codable, Sendable {
    let text: String
}
