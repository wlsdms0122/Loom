import Testing
@testable import Platform

/// SystemInfo 구조체를 검증한다.
@Suite("SystemInfo")
struct SystemInfoTests {
    // MARK: - Public
    @Test("SystemInfo가 주어진 값으로 초기화된다")
    func initialization() {
        let info = SystemInfo(
            osName: "macOS",
            osVersion: "14.0.0",
            architecture: "arm64"
        )

        #expect(info.osName == "macOS")
        #expect(info.osVersion == "14.0.0")
        #expect(info.architecture == "arm64")
    }

    @Test("SystemInfo가 Sendable을 준수한다")
    func sendableConformance() async {
        let info = SystemInfo(
            osName: "macOS",
            osVersion: "14.0.0",
            architecture: "arm64"
        )

        let result = await Task {
            info.osName
        }.value

        #expect(result == "macOS")
    }
}
