import Foundation

/// Web UI 테스트에서 공통으로 사용하는 상수 모음.
enum TestConstants {
    // MARK: - Public

    /// index.html 파일 경로를 소스 트리 기준으로 해석한다.
    /// #filePath = .../sample/Tests/LoomSampleTests/WebUITests/TestHelpers/TestConstants.swift
    /// 5회 deletingLastPathComponent로 .../sample/ 에 도달한다.
    static let htmlURL: URL = {
        var url = URL(fileURLWithPath: #filePath)
        // TestConstants.swift -> TestHelpers -> WebUITests -> LoomSampleTests -> Tests -> sample
        for _ in 0..<5 {
            url = url.deletingLastPathComponent()
        }
        return url.appendingPathComponent("Sources/LoomSample/Resources/web/index.html")
    }()

    static let expectedInputIDs = [
        "nameInput", "clipInput", "alertStyle", "fileTypeFilter",
        "fileMultiple", "saveDefaultName", "fsPath", "fsContent",
        "shellUrl", "shellPath", "eventName", "errorScenario"
    ]

    static let expectedStatusIDs = [
        "greetStatus", "clipStatus", "alertStatus", "openFileStatus",
        "saveFileStatus", "fsStatus", "shellStatus", "eventStatus", "errorStatus"
    ]

    static let expectedCardTitles = [
        "Greeter", "Clipboard", "Native Alerts", "Open File",
        "Save File", "File System", "Shell", "Events", "Error Handling"
    ]

    static let requiredCSSVariables = [
        "--bg", "--card-bg", "--text", "--accent",
        "--secondary", "--border", "--success", "--error",
        "--space-xs", "--space-sm", "--space-md",
        "--space-lg", "--space-xl", "--space-2xl"
    ]
}
