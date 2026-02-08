/// 의존성 주입 컨테이너의 Actor 기반 구현체.
public actor ContainerActor: Container {
    // MARK: - Property
    private var entries: [ObjectIdentifier: Entry] = [:]
    private var singletonCache: [ObjectIdentifier: any Sendable] = [:]
    private let logger: (any Logger)?

    // MARK: - Initializer
    public init(logger: (any Logger)? = nil) {
        self.logger = logger
    }

    // MARK: - Public
    public func register<T: Sendable>(
        _ type: T.Type,
        scope: Scope,
        factory: @escaping @Sendable () -> T
    ) {
        let key = ObjectIdentifier(type)
        entries[key] = Entry(scope: scope, factory: factory)
        // 재등록 시 기존 싱글턴 캐시를 제거한다.
        singletonCache.removeValue(forKey: key)
    }

    public func resolve<T: Sendable>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)
        guard let entry = entries[key],
              let factory = entry.factory as? @Sendable () -> T else {
            logger?.warning("Failed to resolve dependency: \(type)")
            return nil
        }

        switch entry.scope {
        case .singleton:
            if let cached = singletonCache[key] as? T {
                return cached
            }
            let instance = factory()
            singletonCache[key] = instance
            return instance

        case .transient:
            return factory()
        }
    }
}

// MARK: - Private
extension ContainerActor {
    /// 등록 항목을 저장하는 내부 구조체.
    private struct Entry {
        let scope: Scope
        let factory: any Sendable
    }
}
