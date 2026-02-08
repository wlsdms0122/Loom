import AppKit
import Platform

/// macOS 메뉴바 상태 아이템 구현체. NSStatusItem을 래핑한다.
// 안전성: @unchecked Sendable — 이 타입은 @MainActor로 격리되어 있다.
// 모든 접근이 메인 스레드에서 직렬화된다.
@MainActor
public final class MacOSStatusItem: StatusItem, @unchecked Sendable {
    // MARK: - Property
    private var statusItem: NSStatusItem?
    private let menuBuilder: MacOSMenuBuilder

    // MARK: - Initializer
    public init() {
        self.menuBuilder = MacOSMenuBuilder()
    }

    // MARK: - Public
    public func setTitle(_ title: String) {
        ensureStatusItem()
        statusItem?.button?.title = title
    }

    public func setIcon(_ iconName: String) {
        ensureStatusItem()
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            statusItem?.button?.image = image
            statusItem?.button?.imagePosition = .imageLeading
        }
    }

    public func setMenu(_ items: [MenuItem]) {
        ensureStatusItem()
        statusItem?.menu = menuBuilder.build(from: items)
    }

    public func show() {
        ensureStatusItem()
        statusItem?.isVisible = true
    }

    public func hide() {
        statusItem?.isVisible = false
    }

    // MARK: - Private
    private func ensureStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(
                withLength: NSStatusItem.variableLength
            )
        }
    }
}
