import Foundation
import Core

/// 플러그인에 주입되는 컨텍스트. 플러그인이 프레임워크 서비스에 접근할 수 있도록 한다.
public protocol PluginContext: Sendable {
    /// 의존성 주입 컨테이너 (읽기 전용).
    var container: any ContainerResolver { get }

    /// 이벤트 버스.
    var eventBus: any EventBus { get }

    /// 로거.
    var logger: any Logger { get }

    /// Swift에서 웹으로 이벤트를 전송한다.
    func emit(event: String, data: String) async throws
}

// MARK: - Encodable Emit

extension PluginContext {
    /// Encodable 타입을 JSON 문자열로 직렬화하여 이벤트를 전송한다.
    public func emit<T: Encodable & Sendable>(event: String, data: T) async throws {
        let jsonData = try JSONEncoder().encode(data)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        try await emit(event: event, data: jsonString)
    }
}
