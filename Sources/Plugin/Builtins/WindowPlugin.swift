import Foundation
import Core
import Platform

/// 윈도우 플러그인. 윈도우 드래그 등 윈도우 제어 기능을 제공한다.
public struct WindowPlugin: Plugin, Sendable {
    // MARK: - Property

    public let name = "window"
    private let windowManagerStorage: PlatformServiceStorage<any WindowManager>
    private let windowHandle: WindowHandle

    // MARK: - Initializer

    public init(windowHandle: WindowHandle) {
        self.windowManagerStorage = PlatformServiceStorage()
        self.windowHandle = windowHandle
    }

    // MARK: - Public

    public func initialize(context: any PluginContext) async throws {
        if let wm = await context.container.resolve((any WindowManager).self) {
            windowManagerStorage.update(wm)
        }
    }

    public func methods() async -> [PluginMethod] {
        let storage = windowManagerStorage
        let handle = windowHandle
        return [
            PluginMethod(name: "startDrag") {
                guard let wm = storage.current else {
                    throw PluginError.unsupportedPlatform
                }
                await wm.performDrag(handle)
            }
        ]
    }
}
