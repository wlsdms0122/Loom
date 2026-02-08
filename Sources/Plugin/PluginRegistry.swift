/// 플러그인 등록 및 관리 프로토콜.
public protocol PluginRegistry: Sendable {
    /// 플러그인을 등록한다.
    func register(_ plugin: any Plugin) async

    /// 이름으로 플러그인을 조회한다.
    func plugin(named name: String) async -> (any Plugin)?

    /// 등록된 모든 플러그인을 초기화한다.
    func initializeAll(context: any PluginContext) async throws

    /// 등록된 모든 플러그인을 해제한다.
    func disposeAll() async

    /// 등록된 모든 플러그인을 반환한다.
    func allPlugins() async -> [any Plugin]
}
