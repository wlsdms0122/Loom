import Testing
import Foundation
@testable import Core
@testable import Plugin
import LoomTestKit

@Suite("ProcessPlugin 테스트")
struct ProcessPluginTests {
    // MARK: - Property

    private let sandbox: PathSandbox

    // MARK: - Initializer

    init() {
        // /bin, /usr/bin 경로를 허용하여 기본 명령어 실행을 허용한다.
        sandbox = PathSandbox(allowedDirectories: ["/bin", "/usr/bin"])
    }

    // MARK: - 메서드 등록 테스트

    @Test("methods()에서 execute 메서드를 반환한다")
    func methodsContainsExecute() async {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let methods = await plugin.methods()

        #expect(methods.count == 1)
        #expect(methods.first?.name == "execute")
    }

    @Test("플러그인 이름이 process이다")
    func pluginName() {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        #expect(plugin.name == "process")
    }

    // MARK: - SecurityPolicy 필수 테스트

    @Test("init(securityPolicy:)로만 생성 가능하다")
    func initRequiresSecurityPolicy() {
        // securityPolicy 파라미터를 전달하여 정상 생성됨을 확인한다.
        // 기본 init()은 @available(*, unavailable)로 컴파일 타임에 차단된다.
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        #expect(plugin.name == "process")
    }

    // MARK: - execute 명령어 실행 테스트

    @Test("유효한 명령어를 실행하고 stdout을 반환한다")
    func executeValidCommand() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/echo","arguments":["hello","world"]}
        """
        let result = try await method.handler(payload)

        // JSON 결과에서 stdout 값을 확인한다.
        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode(ExecuteResultDTO.self, from: data)
        #expect(decoded.exitCode == 0)
        #expect(decoded.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello world")
        #expect(decoded.stderr == "")
    }

    @Test("인자 없이 명령어를 실행할 수 있다")
    func executeCommandWithoutArguments() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/usr/bin/whoami"}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode(ExecuteResultDTO.self, from: data)
        #expect(decoded.exitCode == 0)
        #expect(!decoded.stdout.isEmpty)
    }

    @Test("종료 코드가 0이 아닌 명령어도 결과를 반환한다")
    func executeCommandWithNonZeroExitCode() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        // /bin/sh -c "exit 42"로 비정상 종료 코드를 반환한다.
        // /bin을 허용하므로 /bin/sh 사용 가능.
        let payload = """
        {"command":"/bin/sh","arguments":["-c","exit 42"]}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode(ExecuteResultDTO.self, from: data)
        #expect(decoded.exitCode == 42)
    }

    @Test("stderr 출력을 캡처한다")
    func executeCapuresStderr() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/sh","arguments":["-c","echo error_msg >&2"]}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode(ExecuteResultDTO.self, from: data)
        #expect(decoded.stderr.contains("error_msg"))
    }

    // MARK: - SecurityPolicy 거부 테스트

    @Test("SecurityPolicy가 경로를 거부하면 에러를 반환한다")
    func executeBlockedBySecurityPolicy() async throws {
        // /tmp만 허용하는 샌드박스를 사용하여 /bin/echo를 차단한다.
        let restrictiveSandbox = PathSandbox(allowedDirectories: ["/tmp"])
        let plugin = ProcessPlugin(securityPolicy: restrictiveSandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/echo","arguments":["blocked"]}
        """
        await #expect(throws: (any Error).self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("허용되지 않은 경로의 명령어를 거부한다")
    func executeRejectsDisallowedPath() async throws {
        let restrictiveSandbox = PathSandbox(allowedDirectories: ["/usr/local/bin"])
        let plugin = ProcessPlugin(securityPolicy: restrictiveSandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/ls"}
        """
        await #expect(throws: (any Error).self) {
            _ = try await method.handler(payload)
        }
    }

    // MARK: - JSON 디코딩 에러 테스트

    @Test("잘못된 JSON을 전달하면 디코딩 에러가 발생한다")
    func executeInvalidJSON() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        await #expect(throws: (any Error).self) {
            _ = try await method.handler("invalid json")
        }
    }

    @Test("command 필드가 누락되면 디코딩 에러가 발생한다")
    func executeMissingCommand() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"arguments":["hello"]}
        """
        await #expect(throws: (any Error).self) {
            _ = try await method.handler(payload)
        }
    }

    // MARK: - 비동기 실행 테스트

    @Test("64KB를 초과하는 stdout 출력이 deadlock 없이 반환된다")
    func executeLargeOutput() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/sh","arguments":["-c","dd if=/dev/zero bs=1024 count=128 2>/dev/null | base64"]}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode(ExecuteResultDTO.self, from: data)
        #expect(decoded.exitCode == 0)
        #expect(decoded.stdout.count > 100_000)
    }

    @Test("동시에 여러 프로세스를 실행할 수 있다")
    func executeConcurrently() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/echo","arguments":["concurrent"]}
        """
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let result = try await method.handler(payload)
                    let data = Data(result.utf8)
                    let decoded = try JSONDecoder().decode(ExecuteResultDTO.self, from: data)
                    #expect(decoded.exitCode == 0)
                    #expect(decoded.stdout.contains("concurrent"))
                }
            }
            try await group.waitForAll()
        }
    }

    // MARK: - cwd 검증 테스트

    @Test("허용되지 않은 cwd 경로를 거부한다")
    func executeRejectsDisallowedCwd() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/echo","arguments":["test"],"cwd":"/tmp"}
        """
        await #expect(throws: (any Error).self) {
            _ = try await method.handler(payload)
        }
    }

    @Test("cwd가 nil이면 검증을 건너뛴다")
    func executeWithoutCwdSkipsValidation() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/echo","arguments":["no-cwd"]}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode(ExecuteResultDTO.self, from: data)
        #expect(decoded.exitCode == 0)
        #expect(decoded.stdout.contains("no-cwd"))
    }

    // MARK: - 타임아웃 테스트

    @Test("타임아웃 내에 완료되면 정상 결과를 반환한다")
    func executeWithinTimeout() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/echo","arguments":["fast"],"timeout":10}
        """
        let result = try await method.handler(payload)

        let data = Data(result.utf8)
        let decoded = try JSONDecoder().decode(ExecuteResultDTO.self, from: data)
        #expect(decoded.exitCode == 0)
        #expect(decoded.stdout.contains("fast"))
    }

    @Test("타임아웃을 초과하면 에러를 반환하고 프로세스를 종료한다")
    func executeTimedOut() async throws {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        let method = try #require(await plugin.methods().first { $0.name == "execute" })

        let payload = """
        {"command":"/bin/sleep","arguments":["60"],"timeout":1}
        """
        await #expect(throws: (any Error).self) {
            _ = try await method.handler(payload)
        }
    }

    // MARK: - dispose 테스트

    @Test("dispose가 에러 없이 완료된다")
    func disposeSucceeds() async {
        let plugin = ProcessPlugin(securityPolicy: sandbox)
        await plugin.dispose()
    }
}

// MARK: - DTO

/// 테스트에서 execute 결과를 디코딩하기 위한 DTO.
private struct ExecuteResultDTO: Decodable, Sendable {
    let exitCode: Int
    let stdout: String
    let stderr: String
}
