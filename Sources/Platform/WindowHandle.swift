/// 윈도우 핸들 구조체. 플랫폼별 윈도우를 식별한다.
public struct WindowHandle: Sendable, Hashable {
    // MARK: - Property
    /// 윈도우 고유 식별자.
    public let id: String

    /// 윈도우 제목.
    public let title: String

    // MARK: - Initializer
    public init(id: String, title: String = "") {
        self.id = id
        self.title = title
    }
}
