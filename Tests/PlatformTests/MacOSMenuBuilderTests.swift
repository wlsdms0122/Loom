import AppKit
import Testing
@testable import Platform
@testable import PlatformMacOS

/// MacOSMenuBuilder의 NSMenu 빌드를 검증한다.
@Suite("MacOSMenuBuilder", .serialized)
@MainActor
struct MacOSMenuBuilderTests {
    // MARK: - Property
    private let builder: MacOSMenuBuilder

    // MARK: - Initializer
    init() {
        builder = MacOSMenuBuilder()
    }

    // MARK: - Build: basic

    @Test("빈 배열로 빌드하면 빈 NSMenu를 반환한다")
    func buildEmpty() {
        let menu = builder.build(from: [])

        #expect(menu.items.isEmpty)
    }

    @Test("일반 아이템을 빌드한다")
    func buildItem() {
        let items = [MenuItem.item(title: "열기", key: "o") {}]
        let menu = builder.build(from: items)

        #expect(menu.items.count == 1)
        #expect(menu.items[0].title == "열기")
        #expect(menu.items[0].keyEquivalent == "o")
    }

    @Test("키 없는 아이템을 빌드하면 keyEquivalent가 빈 문자열이다")
    func buildItemNoKey() {
        let items = [MenuItem.item(title: "실행") {}]
        let menu = builder.build(from: items)

        #expect(menu.items[0].keyEquivalent == "")
    }

    // MARK: - Build: separator

    @Test("구분선을 빌드한다")
    func buildSeparator() {
        let items: [MenuItem] = [
            .item(title: "위") {},
            .separator(),
            .item(title: "아래") {}
        ]
        let menu = builder.build(from: items)

        #expect(menu.items.count == 3)
        #expect(menu.items[1].isSeparatorItem)
    }

    // MARK: - Build: submenu

    @Test("하위 메뉴를 빌드한다")
    func buildSubmenu() {
        let items: [MenuItem] = [
            .submenu(title: "파일", items: [
                .item(title: "새 파일") {},
                .item(title: "열기", key: "o") {}
            ])
        ]
        let menu = builder.build(from: items)

        #expect(menu.items.count == 1)
        #expect(menu.items[0].title == "파일")
        #expect(menu.items[0].submenu != nil)
        #expect(menu.items[0].submenu?.items.count == 2)
        #expect(menu.items[0].submenu?.items[0].title == "새 파일")
        #expect(menu.items[0].submenu?.items[1].title == "열기")
    }

    // MARK: - Build: action target

    @Test("아이템 액션이 target에 연결된다")
    func actionTarget() {
        let items = [MenuItem.item(title: "테스트") {}]
        let menu = builder.build(from: items)

        let nsItem = menu.items[0]
        #expect(nsItem.target != nil)
        #expect(nsItem.action != nil)
    }

    @Test("액션이 없는 아이템은 action selector가 nil이다")
    func noActionSelector() {
        let items: [MenuItem] = [
            MenuItem(
                title: "액션 없음",
                action: nil,
                keyEquivalent: nil,
                submenu: nil,
                isSeparator: false
            )
        ]
        let menu = builder.build(from: items)

        let nsItem = menu.items[0]
        #expect(nsItem.action == nil)
    }

    // MARK: - Build: standard action presets

    @Test("표준 프리셋은 responder chain selector를 설정하고 target이 nil이다")
    func standardActionPreset() {
        let items: [MenuItem] = [
            .copy()
        ]
        let menu = builder.build(from: items)

        let nsItem = menu.items[0]
        #expect(nsItem.title == "Copy")
        #expect(nsItem.keyEquivalent == "c")
        #expect(nsItem.action == Selector(("copy:")))
        #expect(nsItem.target == nil)
    }

    @Test("표준 프리셋 여러 개를 빌드한다")
    func standardActionMultiple() {
        let items: [MenuItem] = [
            .cut(),
            .copy(),
            .paste(),
        ]
        let menu = builder.build(from: items)

        #expect(menu.items.count == 3)
        #expect(menu.items[0].action == Selector(("cut:")))
        #expect(menu.items[0].target == nil)
        #expect(menu.items[1].action == Selector(("copy:")))
        #expect(menu.items[1].target == nil)
        #expect(menu.items[2].action == Selector(("paste:")))
        #expect(menu.items[2].target == nil)
    }

    // MARK: - Build: multiple items

    @Test("여러 아이템을 빌드한다")
    func buildMultipleItems() {
        let items: [MenuItem] = [
            .item(title: "A") {},
            .item(title: "B", key: "b") {},
            .separator(),
            .item(title: "C") {}
        ]
        let menu = builder.build(from: items)

        #expect(menu.items.count == 4)
        #expect(menu.items[0].title == "A")
        #expect(menu.items[1].title == "B")
        #expect(menu.items[2].isSeparatorItem)
        #expect(menu.items[3].title == "C")
    }

    // MARK: - Build: nested submenu

    @Test("중첩된 하위 메뉴를 빌드한다")
    func buildNestedSubmenu() {
        let items: [MenuItem] = [
            .submenu(title: "레벨1", items: [
                .submenu(title: "레벨2", items: [
                    .item(title: "항목") {}
                ])
            ])
        ]
        let menu = builder.build(from: items)

        let level1 = menu.items[0]
        #expect(level1.submenu?.items.count == 1)

        let level2 = level1.submenu?.items[0]
        #expect(level2?.submenu?.items.count == 1)
        #expect(level2?.submenu?.items[0].title == "항목")
    }

    // MARK: - Build: rebuild

    @Test("빌드를 두 번 호출하면 새로운 메뉴를 반환한다")
    func rebuildProducesNewMenu() {
        let items1 = [MenuItem.item(title: "첫 번째") {}]
        let items2 = [MenuItem.item(title: "두 번째") {}]

        let menu1 = builder.build(from: items1)
        let menu2 = builder.build(from: items2)

        #expect(menu1.items[0].title == "첫 번째")
        #expect(menu2.items[0].title == "두 번째")
        #expect(menu1 !== menu2)
    }
}
