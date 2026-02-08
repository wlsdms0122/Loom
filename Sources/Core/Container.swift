/// 의존성 스코프 열거형.
public enum Scope: Sendable {
    /// 캐시됨 - 매번 동일한 인스턴스를 반환한다.
    case singleton
    /// 팩토리 - 호출할 때마다 새 인스턴스를 생성한다.
    case transient
}

/// 의존성 주입 컨테이너의 읽기 전용 뷰.
public protocol ContainerResolver: Sendable {
    /// 등록된 타입의 인스턴스를 반환한다.
    func resolve<T: Sendable>(_ type: T.Type) async -> T?
}

/// 의존성 주입 컨테이너 프로토콜 (읽기 + 쓰기).
public protocol Container: ContainerResolver {
    /// 타입에 대한 팩토리를 등록한다.
    func register<T: Sendable>(
        _ type: T.Type,
        scope: Scope,
        factory: @escaping @Sendable () -> T
    ) async
}

extension Container {
    /// 기본 스코프(.transient)로 팩토리를 등록한다.
    public func register<T: Sendable>(
        _ type: T.Type,
        factory: @escaping @Sendable () -> T
    ) async {
        await register(type, scope: .transient, factory: factory)
    }
}
