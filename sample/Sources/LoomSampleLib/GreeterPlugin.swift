import Foundation
import Core
import Plugin

// MARK: - DTO

/// hello 메서드의 인자.
private struct HelloArgs: Codable, Sendable {
    let name: String
}

/// hello 메서드의 결과.
private struct HelloResult: Codable, Sendable {
    let message: String
}

// MARK: - GreeterPlugin

public struct GreeterPlugin: Plugin {
    // MARK: - Property

    public let name = "greeter"

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func methods() async -> [PluginMethod] {
        [
            PluginMethod(name: "hello") { (args: HelloArgs) -> HelloResult in
                HelloResult(message: "Hello, \(args.name)! Welcome to Loom.")
            }
        ]
    }
}
