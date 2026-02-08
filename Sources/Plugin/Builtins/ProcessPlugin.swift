import Foundation
import Core

/// 외부 프로세스를 실행하는 내장 플러그인.
public struct ProcessPlugin: Plugin, Sendable {
    // MARK: - Property

    public let name = "process"

    private let securityPolicy: any SecurityPolicy

    // MARK: - Initializer

    @available(*, unavailable, message: "SecurityPolicy is required. Use init(securityPolicy:) instead.")
    public init() {
        fatalError("SecurityPolicy is required")
    }

    public init(securityPolicy: any SecurityPolicy) {
        self.securityPolicy = securityPolicy
    }

    // MARK: - Public

    public func methods() async -> [PluginMethod] {
        [
            PluginMethod(name: "execute") { [securityPolicy] (args: ExecuteArgs) -> ExecuteResult in
                // 실행 파일 경로를 보안 정책으로 검증한다.
                _ = try securityPolicy.validatePath(args.command)

                // 작업 디렉터리를 보안 정책으로 검증한다.
                let resolvedCwd: URL?
                if let cwd = args.cwd {
                    resolvedCwd = try securityPolicy.validatePath(cwd)
                } else {
                    resolvedCwd = nil
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: args.command)
                process.arguments = args.arguments ?? []
                process.currentDirectoryURL = resolvedCwd

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let stdoutAccumulator = DataAccumulator()
                let stderrAccumulator = DataAccumulator()

                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    stdoutAccumulator.append(handle.availableData)
                }
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    stderrAccumulator.append(handle.availableData)
                }

                try Task.checkCancellation()

                let runProcess: @Sendable () async throws -> ExecuteResult = {
                    try await withTaskCancellationHandler {
                        try await withCheckedThrowingContinuation { continuation in
                            process.terminationHandler = { _ in
                                // 핸들러를 해제하고 남은 데이터를 읽는다.
                                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                                stderrPipe.fileHandleForReading.readabilityHandler = nil

                                stdoutAccumulator.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                                stderrAccumulator.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                                continuation.resume(returning: ExecuteResult(
                                    exitCode: Int(process.terminationStatus),
                                    stdout: String(data: stdoutAccumulator.data, encoding: .utf8) ?? "",
                                    stderr: String(data: stderrAccumulator.data, encoding: .utf8) ?? ""
                                ))
                            }

                            do {
                                try process.run()
                            } catch {
                                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                                stderrPipe.fileHandleForReading.readabilityHandler = nil
                                continuation.resume(throwing: error)
                            }
                        }
                    } onCancel: {
                        if process.isRunning {
                            process.terminate()
                        }
                    }
                }

                // 타임아웃이 지정되면 네이티브 측에서 프로세스를 강제 종료한다.
                guard let timeout = args.timeout else {
                    return try await runProcess()
                }

                return try await withThrowingTaskGroup(of: ExecuteResult.self) { group in
                    group.addTask { try await runProcess() }
                    group.addTask {
                        try await Task.sleep(for: .seconds(timeout))
                        throw PluginError.custom("프로세스가 \(Int(timeout))초 후 타임아웃되었습니다.")
                    }

                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
            }
        ]
    }
}

// MARK: - DTO

/// 프로세스 실행 인자.
private struct ExecuteArgs: Decodable, Sendable {
    let command: String
    let arguments: [String]?
    let cwd: String?
    /// 프로세스 실행 제한 시간(초). nil이면 타임아웃 없이 완료까지 대기한다.
    let timeout: TimeInterval?
}

/// 프로세스 실행 결과.
private struct ExecuteResult: Encodable, Sendable {
    let exitCode: Int
    let stdout: String
    let stderr: String
}

// MARK: - DataAccumulator

/// 파이프 출력을 수집하기 위한 스레드 안전 데이터 누적기.
private final class DataAccumulator: @unchecked Sendable {
    // @unchecked Sendable 안전성: NSLock으로 buffer 접근을 직렬화한다.
    private let lock = NSLock()
    private var buffer = Data()

    var data: Data {
        lock.withLock { buffer }
    }

    func append(_ newData: Data) {
        guard !newData.isEmpty else { return }
        lock.withLock { buffer.append(newData) }
    }
}
