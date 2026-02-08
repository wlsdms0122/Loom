import Foundation

/// 플랫폼 서비스를 스레드 안전하게 저장하는 범용 래퍼.
// 안전성: @unchecked Sendable — 모든 가변 상태(`_service`)는 `lock`(NSLock)으로 보호된다.
// `current`와 `update` 모두 lock을 획득한다.
final class PlatformServiceStorage<Service: Sendable>: @unchecked Sendable {
    // MARK: - Property

    private let lock = NSLock()
    private var _service: Service?
    private let _defaultValue: Service?

    /// 현재 저장된 서비스를 반환한다. 서비스가 없으면 기본값을 반환한다.
    var current: Service? {
        lock.lock()
        defer { lock.unlock() }
        return _service ?? _defaultValue
    }

    // MARK: - Initializer

    init(service: Service? = nil) {
        self._service = service
        self._defaultValue = nil
    }

    /// 기본값을 지정하여 스토리지를 생성한다. `update`가 호출되기 전까지 기본값을 반환한다.
    init(defaultValue: Service) {
        self._service = nil
        self._defaultValue = defaultValue
    }

    // MARK: - Internal

    func update(_ service: Service) {
        lock.lock()
        defer { lock.unlock() }
        _service = service
    }
}
