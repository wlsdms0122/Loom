import Testing
@testable import Plugin

/// PluginError의 localizedDescription, Equatable, 연관값을 검증한다.
@Suite("PluginError")
struct PluginErrorTests {
    // MARK: - localizedDescription

    @Test("localizedDescription이 의미 있는 메시지를 반환한다")
    func localizedDescription() {
        #expect(
            PluginError.invalidArguments.localizedDescription
            == "플러그인 메서드에 잘못된 인자가 전달되었습니다."
        )
        #expect(
            PluginError.unsupportedPlatform.localizedDescription
            == "현재 플랫폼에서 지원하지 않는 기능입니다."
        )
        #expect(
            PluginError.notInitialized.localizedDescription
            == "플러그인이 초기화되지 않았습니다."
        )
        #expect(
            PluginError.blockedURLScheme("javascript").localizedDescription
            == "허용되지 않은 URL 스킴입니다: javascript"
        )
        #expect(
            PluginError.custom("Something went wrong").localizedDescription
            == "Something went wrong"
        )
    }

    @Test("blockedPath의 localizedDescription에 경로가 포함된다")
    func blockedPathDescription() {
        let error = PluginError.blockedPath("/etc/passwd")
        #expect(error.localizedDescription == "허용되지 않은 경로입니다: /etc/passwd")
    }

    @Test("encodingFailed의 localizedDescription이 올바르다")
    func encodingFailedDescription() {
        #expect(
            PluginError.encodingFailed.localizedDescription
            == "JSON 인코딩에 실패했습니다."
        )
    }

    // MARK: - Equatable

    @Test("같은 케이스는 동일하다")
    func equalCases() {
        #expect(PluginError.invalidArguments == PluginError.invalidArguments)
        #expect(PluginError.unsupportedPlatform == PluginError.unsupportedPlatform)
        #expect(PluginError.notInitialized == PluginError.notInitialized)
        #expect(PluginError.encodingFailed == PluginError.encodingFailed)
    }

    @Test("다른 케이스는 동일하지 않다")
    func differentCases() {
        #expect(PluginError.invalidArguments != PluginError.notInitialized)
        #expect(PluginError.unsupportedPlatform != PluginError.encodingFailed)
    }

    @Test("같은 연관값을 가진 케이스는 동일하다")
    func equalAssociatedValues() {
        #expect(PluginError.blockedURLScheme("file") == PluginError.blockedURLScheme("file"))
        #expect(PluginError.blockedPath("/tmp") == PluginError.blockedPath("/tmp"))
        #expect(PluginError.custom("error") == PluginError.custom("error"))
    }

    @Test("다른 연관값을 가진 케이스는 동일하지 않다")
    func differentAssociatedValues() {
        #expect(PluginError.blockedURLScheme("file") != PluginError.blockedURLScheme("javascript"))
        #expect(PluginError.blockedPath("/tmp") != PluginError.blockedPath("/etc"))
        #expect(PluginError.custom("a") != PluginError.custom("b"))
    }

    // MARK: - Error Conformance

    @Test("Error 프로토콜을 준수하여 throw/catch가 동작한다")
    func throwAndCatch() {
        do {
            throw PluginError.notInitialized
        } catch let error as PluginError {
            #expect(error == .notInitialized)
        } catch {
            Issue.record("Expected PluginError")
        }
    }

    @Test("Sendable을 준수하여 Task 간 전달이 가능하다")
    func sendableConformance() async {
        let error = PluginError.custom("sendable test")
        let result = await Task {
            error.localizedDescription
        }.value
        #expect(result == "sendable test")
    }
}
