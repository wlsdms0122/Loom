import Foundation

/// 파일 변경 감시 프로토콜.
public protocol FileWatcher: Sendable {
    func start(watching directory: String, onChange: @escaping @Sendable () -> Void) throws
    func stop()
}
