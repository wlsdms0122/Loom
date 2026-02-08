import Foundation
import Core
import Plugin

// MARK: - DTO

/// emit 메서드의 인자.
private struct EmitArgs: Codable, Sendable {
    let event: String
    let data: String?
}

// MARK: - EventDemoPlugin

// SAFETY: @unchecked Sendable — `context`는 initialize/dispose에서만 변경되며,
// 플러그인 라이프사이클에 의해 직렬로 호출된다.
public final class EventDemoPlugin: Plugin, @unchecked Sendable {
    // MARK: - Property

    public let name = "eventDemo"
    private var context: (any PluginContext)?

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func initialize(context: any PluginContext) async throws {
        self.context = context
    }

    public func methods() async -> [PluginMethod] {
        [
            PluginMethod(name: "emit") { [weak self] (args: EmitArgs) -> [String: String] in
                guard let context = self?.context else {
                    throw PluginError.notInitialized
                }

                let data = args.data ?? "{\"timestamp\":\(Date().timeIntervalSince1970)}"
                try await context.emit(event: args.event, data: data)

                return [:]
            }
        ]
    }

    public func dispose() async {
        context = nil
    }
}
