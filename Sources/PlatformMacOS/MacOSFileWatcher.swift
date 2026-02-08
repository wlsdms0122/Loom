import Foundation
import CoreServices
import Platform

/// macOS 파일 변경 감시 구현체. FSEvents API를 사용한다.
///
// 안전성: FSEventStreamRef가 Sendable이 아니고 FSEventStream C 콜백이 Actor 패턴 채택을
// 방해하므로 @unchecked Sendable이 필요하다. 모든 가변 상태(`stream`, `onChange`)는
// `lock`으로 보호되며, FSEvents 콜백은 `queue`에서 디스패치된다.
// `stop()`은 스트림 무효화 전에 `queue.sync`로 큐를 비워 콜백과 해제가
// 경합하지 않도록 보장한다. `CallbackHolder`가 watcher에 대한 weak 참조를
// 유지하므로 watcher가 해제되어도 use-after-free가 발생하지 않는다.
public final class MacOSFileWatcher: FileWatcher, @unchecked Sendable {
    // MARK: - CallbackHolder
    /// FSEvents 콜백에서 watcher에 안전하게 접근하기 위한 홀더.
    /// weak 참조를 사용하여 watcher 해제 시 use-after-free를 방지한다.
    private final class CallbackHolder {
        weak var watcher: MacOSFileWatcher?

        init(_ watcher: MacOSFileWatcher) {
            self.watcher = watcher
        }
    }

    // MARK: - Property
    private var stream: FSEventStreamRef?
    private var holder: CallbackHolder?
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.loom.filewatcher")
    private var onChange: (@Sendable () -> Void)?

    // MARK: - Initializer
    public init() {}

    deinit {
        stop()
    }

    // MARK: - Public
    public func start(watching directory: String, onChange: @escaping @Sendable () -> Void) throws {
        stop()

        lock.lock()
        self.onChange = onChange
        lock.unlock()

        let holder = CallbackHolder(self)
        let paths = [directory] as CFArray
        var context = FSEventStreamContext()
        context.info = Unmanaged.passRetained(holder).toOpaque()

        guard let stream = FSEventStreamCreate(
            nil,
            { _, info, _, _, _, _ in
                guard let info else { return }
                let holder = Unmanaged<CallbackHolder>.fromOpaque(info).takeUnretainedValue()
                guard let watcher = holder.watcher else { return }
                watcher.lock.lock()
                let callback = watcher.onChange
                watcher.lock.unlock()
                callback?()
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            // 스트림 생성에 실패했으므로 방금 획득한 retain을 해제한다.
            Unmanaged.passUnretained(holder).release()
            return
        }

        lock.lock()
        self.stream = stream
        self.holder = holder
        lock.unlock()

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        lock.lock()
        guard let stream = self.stream else {
            lock.unlock()
            return
        }
        let holder = self.holder
        self.stream = nil
        self.holder = nil
        self.onChange = nil
        lock.unlock()

        FSEventStreamStop(stream)

        // 무효화 전에 큐의 대기 중인 콜백을 비워 진행 중인 콜백이
        // FSEventStreamInvalidate와 경합하지 않도록 한다.
        queue.sync {}

        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)

        // start()에서의 passRetained(holder)와 균형을 맞춘다.
        if let holder {
            Unmanaged.passUnretained(holder).release()
        }
    }
}
