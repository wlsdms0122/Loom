/// 표준 편집 명령. 플랫폼 레이어에서 적절한 디스패치 방식을 결정하기 위한 내부 식별자.
package enum StandardAction: Sendable {
    case cut
    case copy
    case paste
    case undo
    case redo
    case selectAll
}

/// 메뉴 아이템 모델. 플랫폼에 독립적인 메뉴 구조를 정의한다.
public struct MenuItem: Sendable {
    // MARK: - Property
    public let title: String
    public let action: (@MainActor @Sendable () -> Void)?
    public let keyEquivalent: String?
    public let submenu: [MenuItem]?
    public let isSeparator: Bool

    /// 표준 명령 식별자. 플랫폼 레이어에서만 접근한다.
    package let standardAction: StandardAction?

    // MARK: - Initializer
    package init(
        title: String,
        action: (@MainActor @Sendable () -> Void)?,
        keyEquivalent: String?,
        submenu: [MenuItem]?,
        isSeparator: Bool,
        standardAction: StandardAction? = nil
    ) {
        self.title = title
        self.action = action
        self.keyEquivalent = keyEquivalent
        self.submenu = submenu
        self.isSeparator = isSeparator
        self.standardAction = standardAction
    }

    // MARK: - Factory
    /// 일반 메뉴 아이템을 생성한다.
    public static func item(
        title: String,
        key: String? = nil,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> MenuItem {
        MenuItem(
            title: title,
            action: action,
            keyEquivalent: key,
            submenu: nil,
            isSeparator: false
        )
    }

    /// 구분선 아이템을 생성한다.
    public static func separator() -> MenuItem {
        MenuItem(
            title: "",
            action: nil,
            keyEquivalent: nil,
            submenu: nil,
            isSeparator: true
        )
    }

    /// 하위 메뉴를 포함하는 아이템을 생성한다.
    public static func submenu(title: String, items: [MenuItem]) -> MenuItem {
        MenuItem(
            title: title,
            action: nil,
            keyEquivalent: nil,
            submenu: items,
            isSeparator: false
        )
    }

    // MARK: - Standard Actions
    /// 잘라내기 명령.
    public static func cut(key: String = "x") -> MenuItem {
        MenuItem(
            title: "Cut",
            action: nil,
            keyEquivalent: key,
            submenu: nil,
            isSeparator: false,
            standardAction: .cut
        )
    }

    /// 복사 명령.
    public static func copy(key: String = "c") -> MenuItem {
        MenuItem(
            title: "Copy",
            action: nil,
            keyEquivalent: key,
            submenu: nil,
            isSeparator: false,
            standardAction: .copy
        )
    }

    /// 붙여넣기 명령.
    public static func paste(key: String = "v") -> MenuItem {
        MenuItem(
            title: "Paste",
            action: nil,
            keyEquivalent: key,
            submenu: nil,
            isSeparator: false,
            standardAction: .paste
        )
    }

    /// 실행 취소 명령.
    public static func undo(key: String = "z") -> MenuItem {
        MenuItem(
            title: "Undo",
            action: nil,
            keyEquivalent: key,
            submenu: nil,
            isSeparator: false,
            standardAction: .undo
        )
    }

    /// 다시 실행 명령.
    public static func redo(key: String = "Z") -> MenuItem {
        MenuItem(
            title: "Redo",
            action: nil,
            keyEquivalent: key,
            submenu: nil,
            isSeparator: false,
            standardAction: .redo
        )
    }

    /// 전체 선택 명령.
    public static func selectAll(key: String = "a") -> MenuItem {
        MenuItem(
            title: "Select All",
            action: nil,
            keyEquivalent: key,
            submenu: nil,
            isSeparator: false,
            standardAction: .selectAll
        )
    }
}
