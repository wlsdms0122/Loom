import AppKit
import Foundation
import Platform

/// macOS 셸 유틸리티 구현체. NSWorkspace를 래핑한다.
@MainActor
public final class MacOSShell: Shell, @unchecked Sendable {
    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func openURL(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    public func openPath(_ path: String) -> Bool {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }
}
