import Foundation
import os
import Testing
@testable import Platform

/// 테스트용 스레드 안전 플래그. @Sendable 클로저에서 안전하게 사용한다.
private final class FlagBox: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: false)

    var value: Bool {
        storage.withLock { $0 }
    }

    func set() {
        storage.withLock { $0 = true }
    }
}

/// MenuItem 구조체의 생성 및 팩토리 메서드를 검증한다.
@Suite("MenuItem")
struct MenuItemTests {
    // MARK: - Factory: item

    @Test("item 팩토리로 일반 메뉴 아이템을 생성한다")
    func itemFactory() {
        let item = MenuItem.item(title: "열기", key: "o") {}

        #expect(item.title == "열기")
        #expect(item.keyEquivalent == "o")
        #expect(item.isSeparator == false)
        #expect(item.submenu == nil)
        #expect(item.action != nil)
        #expect(item.standardAction == nil)
    }

    @Test("item 팩토리의 액션이 실행된다")
    @MainActor
    func itemFactoryAction() {
        let flag = FlagBox()
        let item = MenuItem.item(title: "열기") { [flag] in
            flag.set()
        }

        guard let handler = item.action else {
            Issue.record("Expected action closure")
            return
        }
        handler()
        let result = flag.value
        #expect(result == true)
    }

    @Test("item 팩토리에서 key를 생략하면 nil이다")
    func itemFactoryNoKey() {
        let item = MenuItem.item(title: "실행") {}

        #expect(item.title == "실행")
        #expect(item.keyEquivalent == nil)
    }

    // MARK: - Factory: Standard Action Presets

    @Test("copy 프리셋이 올바른 속성을 갖는다")
    func copyPreset() {
        let item = MenuItem.copy()

        #expect(item.title == "Copy")
        #expect(item.keyEquivalent == "c")
        #expect(item.standardAction == .copy)
        #expect(item.action == nil)
        #expect(item.isSeparator == false)
        #expect(item.submenu == nil)
    }

    @Test("paste 프리셋이 올바른 속성을 갖는다")
    func pastePreset() {
        let item = MenuItem.paste()

        #expect(item.title == "Paste")
        #expect(item.keyEquivalent == "v")
        #expect(item.standardAction == .paste)
        #expect(item.action == nil)
    }

    @Test("cut 프리셋이 올바른 속성을 갖는다")
    func cutPreset() {
        let item = MenuItem.cut()

        #expect(item.title == "Cut")
        #expect(item.keyEquivalent == "x")
        #expect(item.standardAction == .cut)
        #expect(item.action == nil)
    }

    @Test("undo 프리셋이 올바른 속성을 갖는다")
    func undoPreset() {
        let item = MenuItem.undo()

        #expect(item.title == "Undo")
        #expect(item.keyEquivalent == "z")
        #expect(item.standardAction == .undo)
        #expect(item.action == nil)
    }

    @Test("redo 프리셋이 올바른 속성을 갖는다")
    func redoPreset() {
        let item = MenuItem.redo()

        #expect(item.title == "Redo")
        #expect(item.keyEquivalent == "Z")
        #expect(item.standardAction == .redo)
        #expect(item.action == nil)
    }

    @Test("selectAll 프리셋이 올바른 속성을 갖는다")
    func selectAllPreset() {
        let item = MenuItem.selectAll()

        #expect(item.title == "Select All")
        #expect(item.keyEquivalent == "a")
        #expect(item.standardAction == .selectAll)
        #expect(item.action == nil)
    }

    @Test("프리셋에서 커스텀 키를 지정할 수 있다")
    func presetCustomKey() {
        let item = MenuItem.copy(key: "C")

        #expect(item.title == "Copy")
        #expect(item.keyEquivalent == "C")
        #expect(item.standardAction == .copy)
    }

    // MARK: - Factory: separator

    @Test("separator 팩토리로 구분선을 생성한다")
    func separatorFactory() {
        let item = MenuItem.separator()

        #expect(item.isSeparator == true)
        #expect(item.title == "")
        #expect(item.action == nil)
        #expect(item.keyEquivalent == nil)
        #expect(item.submenu == nil)
    }

    // MARK: - Factory: submenu

    @Test("submenu 팩토리로 하위 메뉴를 생성한다")
    func submenuFactory() {
        let children = [
            MenuItem.item(title: "하위1") {},
            MenuItem.separator(),
            MenuItem.item(title: "하위2") {}
        ]
        let item = MenuItem.submenu(title: "파일", items: children)

        #expect(item.title == "파일")
        #expect(item.isSeparator == false)
        #expect(item.action == nil)
        #expect(item.submenu?.count == 3)
    }

    @Test("submenu의 하위 아이템이 올바른 타입이다")
    func submenuChildTypes() {
        let children = [
            MenuItem.item(title: "A") {},
            MenuItem.separator(),
            MenuItem.item(title: "B", key: "b") {}
        ]
        let item = MenuItem.submenu(title: "편집", items: children)

        let submenuItems = item.submenu!
        #expect(submenuItems[0].isSeparator == false)
        #expect(submenuItems[0].title == "A")
        #expect(submenuItems[1].isSeparator == true)
        #expect(submenuItems[2].keyEquivalent == "b")
    }

    // MARK: - Initializer

    @Test("전체 매개변수로 MenuItem을 직접 초기화한다")
    func directInitialization() {
        let item = MenuItem(
            title: "테스트",
            action: nil,
            keyEquivalent: "t",
            submenu: nil,
            isSeparator: false
        )

        #expect(item.title == "테스트")
        #expect(item.keyEquivalent == "t")
        #expect(item.action == nil)
        #expect(item.submenu == nil)
        #expect(item.isSeparator == false)
        #expect(item.standardAction == nil)
    }

    @Test("standardAction 포함 초기화")
    func directInitializationWithStandardAction() {
        let item = MenuItem(
            title: "붙여넣기",
            action: nil,
            keyEquivalent: "v",
            submenu: nil,
            isSeparator: false,
            standardAction: .paste
        )

        #expect(item.title == "붙여넣기")
        #expect(item.standardAction == .paste)
        #expect(item.action == nil)
    }

    // MARK: - Sendable

    @Test("MenuItem이 Sendable을 준수한다")
    func sendableConformance() async {
        let item = MenuItem.item(title: "전송 테스트") {}

        let result = await Task {
            item.title
        }.value

        #expect(result == "전송 테스트")
    }

    // MARK: - Nested submenu

    @Test("중첩된 하위 메뉴를 생성할 수 있다")
    func nestedSubmenu() {
        let innerSubmenu = MenuItem.submenu(title: "내부", items: [
            MenuItem.item(title: "항목1") {}
        ])
        let outerSubmenu = MenuItem.submenu(title: "외부", items: [
            innerSubmenu,
            MenuItem.item(title: "항목2") {}
        ])

        #expect(outerSubmenu.submenu?.count == 2)
        #expect(outerSubmenu.submenu?[0].submenu?.count == 1)
        #expect(outerSubmenu.submenu?[0].submenu?[0].title == "항목1")
    }

    // MARK: - Empty submenu

    @Test("빈 하위 메뉴를 생성할 수 있다")
    func emptySubmenu() {
        let item = MenuItem.submenu(title: "빈 메뉴", items: [])

        #expect(item.submenu?.isEmpty == true)
    }
}
