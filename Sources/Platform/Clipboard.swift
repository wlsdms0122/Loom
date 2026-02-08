/// 클립보드 접근 프로토콜.
public protocol Clipboard: Sendable {
    /// 클립보드에서 텍스트를 읽는다.
    func readText() async -> String?

    /// 클립보드에 텍스트를 쓴다.
    func writeText(_ text: String) async -> Bool
}
