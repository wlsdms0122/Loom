import AppKit
import Platform

/// NSMenu 메뉴 아이템의 액션 대상. Sendable 클로저를 실행한다.
// 안전성: @unchecked Sendable — 이 타입은 @MainActor로 격리되어 있다.
// 모든 접근이 메인 스레드에서 직렬화된다.
@MainActor
final class MenuItemTarget: NSObject, @unchecked Sendable {
    // MARK: - Property
    private let handler: @MainActor @Sendable () -> Void

    // MARK: - Initializer
    init(handler: @escaping @MainActor @Sendable () -> Void) {
        self.handler = handler
        super.init()
    }

    // MARK: - Action
    @objc func performAction(_ sender: Any?) {
        handler()
    }
}

/// MenuItem 배열로부터 NSMenu를 생성하는 빌더.
// 안전성: @unchecked Sendable — 이 타입은 @MainActor로 격리되어 있다.
// 모든 접근이 메인 스레드에서 직렬화된다.
@MainActor
public final class MacOSMenuBuilder: @unchecked Sendable {
    // MARK: - Property
    private var targets: [MenuItemTarget] = []

    // MARK: - Initializer
    public init() {}

    // MARK: - Public
    /// MenuItem 배열로부터 NSMenu를 빌드한다.
    public func build(from items: [MenuItem]) -> NSMenu {
        targets.removeAll()
        let menu = NSMenu()

        for item in items {
            let nsItem = makeNSMenuItem(from: item)
            menu.addItem(nsItem)
        }

        return menu
    }

    // MARK: - Private
    private func makeNSMenuItem(from item: MenuItem) -> NSMenuItem {
        if item.isSeparator {
            return .separator()
        }

        let keyEquivalent = item.keyEquivalent ?? ""
        let nsItem = NSMenuItem(
            title: item.title,
            action: nil,
            keyEquivalent: keyEquivalent
        )

        // 표준 명령은 responder chain을 통해 디스패치한다.
        if let standardAction = item.standardAction {
            nsItem.action = selector(for: standardAction)
            nsItem.target = nil
        } else if let handler = item.action {
            let target = MenuItemTarget(handler: handler)
            targets.append(target)
            nsItem.target = target
            nsItem.action = #selector(MenuItemTarget.performAction(_:))
        }

        if let submenuItems = item.submenu {
            let submenu = NSMenu(title: item.title)
            for subItem in submenuItems {
                submenu.addItem(makeNSMenuItem(from: subItem))
            }
            nsItem.submenu = submenu
        }

        return nsItem
    }

    private func selector(for action: StandardAction) -> Selector {
        switch action {
        case .cut: #selector(NSText.cut(_:))
        case .copy: #selector(NSText.copy(_:))
        case .paste: #selector(NSText.paste(_:))
        case .undo: Selector(("undo:"))
        case .redo: Selector(("redo:"))
        case .selectAll: #selector(NSStandardKeyBindingResponding.selectAll(_:))
        }
    }
}
