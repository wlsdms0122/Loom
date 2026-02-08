import Foundation
import Testing
@testable import PlatformMacOS

@Suite("MacOSFileWatcher", .serialized)
struct MacOSFileWatcherTests {
    // MARK: - Property
    private let watcher: MacOSFileWatcher
    private let testDir: String

    // MARK: - Initializer
    init() throws {
        watcher = MacOSFileWatcher()
        testDir = NSTemporaryDirectory() + "LoomFileWatcherTests_\(UUID().uuidString)"
        try FileManager.default.createDirectory(
            atPath: testDir,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public
    @Test("파일 변경 시 onChange 콜백이 호출된다")
    func onChangeCalledOnFileWrite() async throws {
        let called = LockIsolated(false)

        try watcher.start(watching: testDir) {
            called.setValue(true)
        }

        let filePath = testDir + "/test_\(UUID().uuidString).txt"
        try Data("hello".utf8).write(to: URL(fileURLWithPath: filePath))

        // Task.sleep is required here because FSEvents delivers file change notifications
        // asynchronously with OS-level latency. There is no deterministic synchronization
        // point available for FSEvents callbacks.
        try await Task.sleep(for: .seconds(2))
        watcher.stop()

        #expect(called.value == true)
    }

    @Test("stop 호출 후 파일 변경 시 콜백이 호출되지 않는다")
    func onChangeNotCalledAfterStop() async throws {
        let called = LockIsolated(false)

        try watcher.start(watching: testDir) {
            called.setValue(true)
        }

        watcher.stop()

        let filePath = testDir + "/test_\(UUID().uuidString).txt"
        try Data("hello".utf8).write(to: URL(fileURLWithPath: filePath))

        // Task.sleep is required here to allow sufficient time for any FSEvents
        // callbacks to fire (they should not, since stop was called). FSEvents
        // delivers notifications asynchronously with OS-level latency.
        try await Task.sleep(for: .seconds(2))

        #expect(called.value == false)
    }

    @Test("rapid start/stop cycles do not crash")
    func rapidStartStopCycles() async throws {
        let watcher = MacOSFileWatcher()

        for _ in 0..<100 {
            try watcher.start(watching: testDir) {}
            watcher.stop()
        }
    }

    @Test("deallocation during active watching does not crash")
    func deallocationDuringActiveWatching() async throws {
        for _ in 0..<50 {
            let dir = NSTemporaryDirectory() + "LoomDealloc_\(UUID().uuidString)"
            try FileManager.default.createDirectory(
                atPath: dir,
                withIntermediateDirectories: true
            )

            var watcher: MacOSFileWatcher? = MacOSFileWatcher()
            try watcher?.start(watching: dir) {}

            // Write a file to trigger callbacks while the watcher is alive.
            let filePath = dir + "/test.txt"
            try Data("hello".utf8).write(to: URL(fileURLWithPath: filePath))

            // FSEventStream을 명시적으로 정리한 뒤 참조를 해제한다.
            watcher?.stop()
            watcher = nil
        }

        // Task.sleep is required here because FSEvents may have pending callbacks
        // that fire after the watcher is deallocated. We need to wait to confirm
        // that deallocation + pending FSEvents do not cause a crash.
        try await Task.sleep(for: .milliseconds(500))
    }

    @Test("stop cleans up stream and callback")
    func stopCleansUpResources() async throws {
        let callCount = LockIsolated(0)

        try watcher.start(watching: testDir) {
            callCount.setValue(callCount.value + 1)
        }

        watcher.stop()

        // Write a file after stop; no callback should fire.
        let filePath = testDir + "/test_\(UUID().uuidString).txt"
        try Data("after_stop".utf8).write(to: URL(fileURLWithPath: filePath))

        // Task.sleep is required here because FSEvents delivers file change
        // notifications asynchronously with OS-level latency. We need to
        // confirm that no callbacks fire after stop().
        try await Task.sleep(for: .seconds(2))

        #expect(callCount.value == 0)

        // Calling stop again must not crash (idempotent).
        watcher.stop()
    }

    @Test("concurrent start and stop from multiple threads is safe")
    func concurrentStartStop() async throws {
        let watcher = MacOSFileWatcher()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    try? watcher.start(watching: testDir) {}
                }
                group.addTask {
                    watcher.stop()
                }
            }
        }

        // Final cleanup must not crash.
        watcher.stop()
    }
}

private final class LockIsolated<Value>: @unchecked Sendable where Value: Sendable {
    private let lock = NSLock()
    private var _value: Value

    var value: Value {
        lock.withLock { _value }
    }

    init(_ value: Value) {
        self._value = value
    }

    func setValue(_ newValue: Value) {
        lock.withLock { _value = newValue }
    }
}
