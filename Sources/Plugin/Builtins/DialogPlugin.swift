import Foundation
import Platform

/// 다이얼로그 플러그인. 파일 열기/저장 패널, 알림 대화상자 기능을 제공한다.
public struct DialogPlugin: Plugin, Sendable {
    // MARK: - Property

    public let name = "dialog"
    private let dialogsStorage: PlatformServiceStorage<any SystemDialogs>

    // MARK: - Initializer

    public init() {
        self.dialogsStorage = PlatformServiceStorage()
    }

    // MARK: - Public

    public func initialize(context: any PluginContext) async throws {
        if let dialogs = await context.container.resolve((any SystemDialogs).self) {
            dialogsStorage.update(dialogs)
        }
    }

    public func methods() async -> [PluginMethod] {
        let storage = dialogsStorage
        return [
            PluginMethod(name: "openFile") { (args: OpenFileArgs) -> [String: [String]] in
                guard let dialogs = storage.current else {
                    throw PluginError.unsupportedPlatform
                }
                let paths = await dialogs.showOpenPanel(
                    title: args.title ?? "Open",
                    allowedFileTypes: args.allowedTypes ?? [],
                    allowsMultipleSelection: args.multiple ?? false,
                    canChooseDirectories: args.directories ?? false
                )
                return ["paths": paths]
            },
            PluginMethod(name: "saveFile") { (args: SaveFileArgs) -> [String: String] in
                guard let dialogs = storage.current else {
                    throw PluginError.unsupportedPlatform
                }
                let path = await dialogs.showSavePanel(
                    title: args.title ?? "Save",
                    defaultFileName: args.defaultName ?? ""
                )
                return ["path": path ?? ""]
            },
            PluginMethod(name: "showAlert") { (args: AlertArgs) -> [String: String] in
                guard let dialogs = storage.current else {
                    throw PluginError.unsupportedPlatform
                }
                let alertStyle: AlertStyle
                switch args.style ?? "informational" {
                case "warning":
                    alertStyle = .warning
                case "critical":
                    alertStyle = .critical
                default:
                    alertStyle = .informational
                }
                let alertResponse = await dialogs.showAlert(
                    title: args.title,
                    message: args.message ?? "",
                    style: alertStyle
                )
                let response: String
                switch alertResponse {
                case .ok:
                    response = "ok"
                case .cancel:
                    response = "cancel"
                case .custom:
                    response = "cancel"
                }
                return ["response": response]
            }
        ]
    }
}

// MARK: - Argument Types

/// 파일 열기 다이얼로그 인자.
private struct OpenFileArgs: Codable, Sendable {
    let title: String?
    let allowedTypes: [String]?
    let multiple: Bool?
    let directories: Bool?
}

/// 파일 저장 다이얼로그 인자.
private struct SaveFileArgs: Codable, Sendable {
    let title: String?
    let defaultName: String?
}

/// 알림 대화상자 인자.
private struct AlertArgs: Codable, Sendable {
    let title: String
    let message: String?
    let style: String?
}
