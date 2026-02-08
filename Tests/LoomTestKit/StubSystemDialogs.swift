import Foundation
import Platform

/// Shared stub SystemDialogs for testing. Returns preconfigured responses.
public final class StubSystemDialogs: SystemDialogs, @unchecked Sendable {
    // MARK: - Property

    private let lock = NSLock()
    private var _alertResponse: AlertResponse
    private var _openPanelPaths: [String]
    private var _savePanelPath: String?

    // MARK: - Initializer

    public init(
        alertResponse: AlertResponse = .ok,
        openPanelPaths: [String] = [],
        savePanelPath: String? = nil
    ) {
        self._alertResponse = alertResponse
        self._openPanelPaths = openPanelPaths
        self._savePanelPath = savePanelPath
    }

    // MARK: - Public

    public func showAlert(
        title: String,
        message: String,
        style: AlertStyle
    ) async -> AlertResponse {
        lock.withLock { _alertResponse }
    }

    public func showOpenPanel(
        title: String,
        allowedFileTypes: [String],
        allowsMultipleSelection: Bool,
        canChooseDirectories: Bool
    ) async -> [String] {
        lock.withLock { _openPanelPaths }
    }

    public func showSavePanel(
        title: String,
        defaultFileName: String
    ) async -> String? {
        lock.withLock { _savePanelPath }
    }
}
