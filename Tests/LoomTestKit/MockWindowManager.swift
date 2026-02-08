import Foundation
import Core
import Platform

/// Shared mock WindowManager for testing. Records all method calls.
public final class MockWindowManager: WindowManager, @unchecked Sendable {
    // MARK: - Property

    private let _lock = NSLock()
    private var _createdConfigurations: [WindowConfiguration] = []
    private var _createdHandles: [WindowHandle] = []
    private var _attachedCount = 0
    private var _attachedWebViews: [(webView: any NativeWebView, handle: WindowHandle)] = []
    private var _shownHandles: [WindowHandle] = []
    private var _closedHandles: [WindowHandle] = []
    private var _draggedHandles: [WindowHandle] = []

    public var createdConfigurations: [WindowConfiguration] { _lock.withLock { _createdConfigurations } }
    public var createdHandles: [WindowHandle] { _lock.withLock { _createdHandles } }
    public var attachedCount: Int { _lock.withLock { _attachedCount } }
    public var attachedWebViewCount: Int { _lock.withLock { _attachedWebViews.count } }
    public var shownHandles: [WindowHandle] { _lock.withLock { _shownHandles } }
    public var closedHandles: [WindowHandle] { _lock.withLock { _closedHandles } }
    public var draggedHandles: [WindowHandle] { _lock.withLock { _draggedHandles } }

    @MainActor public var terminateOnLastWindowClose: Bool = true

    public var windowCount: Int {
        _lock.withLock {
            let closedIDs = Set(_closedHandles.map(\.id))
            return _createdHandles.filter { !closedIDs.contains($0.id) }.count
        }
    }

    // MARK: - Initializer

    public init() {}

    // MARK: - Public

    public func createWindow(configuration: WindowConfiguration) async -> WindowHandle {
        let handle = WindowHandle(id: UUID().uuidString, title: configuration.title)
        _lock.withLock {
            _createdConfigurations.append(configuration)
            _createdHandles.append(handle)
        }
        return handle
    }

    public func createWindow(id: String, configuration: WindowConfiguration) async -> WindowHandle {
        let handle = WindowHandle(id: id, title: configuration.title)
        _lock.withLock {
            _createdConfigurations.append(configuration)
            _createdHandles.append(handle)
        }
        return handle
    }

    public func attachWebView(_ webView: any NativeWebView, to handle: WindowHandle) async {
        _lock.withLock {
            _attachedCount += 1
            _attachedWebViews.append((webView: webView, handle: handle))
        }
    }

    public func closeWindow(_ handle: WindowHandle) async {
        _lock.withLock { _closedHandles.append(handle) }
    }

    public func showWindow(_ handle: WindowHandle) async {
        _lock.withLock { _shownHandles.append(handle) }
    }

    public func performDrag(_ handle: WindowHandle) async {
        _lock.withLock { _draggedHandles.append(handle) }
    }
}
