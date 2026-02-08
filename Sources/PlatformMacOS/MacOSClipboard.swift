import AppKit
import Platform

/// macOS 클립보드 구현체. NSPasteboard를 래핑한다.
@MainActor
public final class MacOSClipboard: Clipboard, @unchecked Sendable {
    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func readText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    public func writeText(_ text: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }
}
