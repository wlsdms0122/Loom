/// 시스템 트레이 / 메뉴바 상태 아이템 프로토콜.
public protocol StatusItem: Sendable {
    /// 상태 아이템의 타이틀을 설정한다.
    @MainActor func setTitle(_ title: String)

    /// 상태 아이템의 아이콘을 설정한다.
    @MainActor func setIcon(_ iconName: String)

    /// 상태 아이템의 메뉴를 설정한다.
    @MainActor func setMenu(_ items: [MenuItem])

    /// 상태 아이템을 표시한다.
    @MainActor func show()

    /// 상태 아이템을 숨긴다.
    @MainActor func hide()
}
