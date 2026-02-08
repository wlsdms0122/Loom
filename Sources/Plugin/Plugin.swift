import Foundation

/// Loom 플러그인의 기본 인터페이스.
/// 플러그인은 Bridge를 통해 웹에서 호출 가능한 네이티브 기능을 제공한다.
public protocol Plugin: Sendable {
    /// 플러그인 고유 이름. Bridge 핸들러 경로의 네임스페이스로 사용된다.
    var name: String { get }

    /// 플러그인을 초기화한다.
    func initialize(context: any PluginContext) async throws

    /// Bridge에 등록할 메서드 목록을 반환한다.
    func methods() async -> [PluginMethod]

    /// 플러그인 리소스를 정리하고 해제한다.
    func dispose() async
}

// MARK: - Default Implementation

extension Plugin {
    public func initialize(context: any PluginContext) async throws {}
    public func dispose() async {}
}
