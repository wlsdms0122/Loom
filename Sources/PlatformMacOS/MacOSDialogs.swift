import AppKit
import UniformTypeIdentifiers
import Core
import Platform

/// macOS 시스템 다이얼로그 구현체.
// 안전성: @unchecked Sendable — 이 타입은 @MainActor로 격리되어 있다.
// 모든 접근이 메인 스레드에서 직렬화된다.
@MainActor
public final class MacOSDialogs: SystemDialogs, @unchecked Sendable {
    // MARK: - Initializer
    public init() {}

    // MARK: - Public
    public func showAlert(
        title: String,
        message: String,
        style: AlertStyle
    ) -> AlertResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message

        switch style {
        case .informational:
            alert.alertStyle = .informational
        case .warning:
            alert.alertStyle = .warning
        case .critical:
            alert.alertStyle = .critical
        }

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            return .ok
        case .alertSecondButtonReturn:
            return .cancel
        default:
            return .custom(response.rawValue)
        }
    }

    public func showOpenPanel(
        title: String,
        allowedFileTypes: [String],
        allowsMultipleSelection: Bool,
        canChooseDirectories: Bool
    ) -> [String] {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canChooseDirectories = canChooseDirectories
        panel.canChooseFiles = !canChooseDirectories

        if !allowedFileTypes.isEmpty {
            panel.allowedContentTypes = allowedFileTypes.compactMap {
                UTType(filenameExtension: $0)
            }
        }

        let response = panel.runModal()
        guard response == .OK else { return [] }
        return panel.urls.map { $0.filePath }
    }

    public func showSavePanel(
        title: String,
        defaultFileName: String
    ) -> String? {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = defaultFileName

        let response = panel.runModal()
        guard response == .OK else { return nil }
        return panel.url?.filePath
    }
}
