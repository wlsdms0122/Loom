/// 애플리케이션 생명주기를 관리하는 진입점.
public protocol Application: Sendable {
    /// 애플리케이션 고유 식별자.
    var id: String { get }

    /// 애플리케이션 설정.
    var configuration: AppConfiguration { get }

    /// 의존성 주입 컨테이너.
    var container: any Container { get }

    /// 애플리케이션을 실행한다.
    func run() async throws

    /// 애플리케이션을 종료한다.
    func terminate() async
}
