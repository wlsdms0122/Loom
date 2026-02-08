import Foundation
import Loom
import LoomSampleLib

// MARK: - Main

@main
struct LoomSampleApp: LoomApplication {
    // MARK: - Property

    var configuration: AppConfiguration {
        let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        return AppConfiguration(
            name: "Loom Sample",
            entry: .bundle(resource: "web/index", extension: "html", in: .module),
            window: WindowConfiguration(
                width: 1000,
                height: 700,
                minWidth: 480,
                minHeight: 360,
                title: "Loom Sample",
                resizable: true
            ),
            debugEntry: .file(sourceURL.appendingPathComponent("Resources/web/index.html"))
        )
    }

    var plugins: [any Plugin] {
        let sandbox = PathSandbox(
            allowedDirectories: [
                NSHomeDirectory(),
                NSTemporaryDirectory()
            ]
        )
        return [
            FileSystemPlugin(securityPolicy: sandbox),
            DialogPlugin(),
            ClipboardPlugin(),
            ShellPlugin(securityPolicy: sandbox),
            ProcessPlugin(securityPolicy: sandbox),
            GreeterPlugin(),
            EventDemoPlugin()
        ]
    }

    var menus: [MenuItem] {
        [
            .submenu(title: "Sample", items: [
                .item(title: "About Loom Sample", key: "i") {
                    // 간단한 About 액션 데모
                    NSLog("[LoomSample] About menu selected")
                },
                .separator(),
                .item(title: "Reload", key: "r") {
                    NSLog("[LoomSample] Reload menu selected")
                }
            ])
        ]
    }
}
