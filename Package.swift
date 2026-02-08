// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Loom",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "Loom",
            targets: ["Loom"]
        ),
        .library(
            name: "LoomCore",
            targets: ["Core"]
        ),
        .library(
            name: "LoomBridge",
            targets: ["Bridge"]
        ),
        .library(
            name: "LoomPlatform",
            targets: ["Platform"]
        ),
        .library(
            name: "LoomPlugin",
            targets: ["Plugin"]
        ),
        .library(
            name: "LoomWebEngine",
            targets: ["WebEngine"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Core",
            dependencies: []),
        .target(
            name: "Bridge",
            dependencies: [
                "Core"
            ]),
        .target(
            name: "Platform",
            dependencies: [
                "Core"
            ]),
        .target(
            name: "PlatformMacOS",
            dependencies: [
                "Core",
                "Platform"
            ]),
        .target(
            name: "Plugin",
            dependencies: [
                "Core",
                "Platform"
            ]),
        .target(
            name: "WebEngine",
            dependencies: [
                "Platform"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "Loom",
            dependencies: [
                "Core",
                "Bridge",
                "Platform",
                "Plugin",
                "WebEngine",
                .target(
                    name: "PlatformMacOS",
                    condition: .when(platforms: [.macOS])
                )
            ]
        ),
        .target(
            name: "LoomTestKit",
            dependencies: [
                "Core",
                "Bridge",
                "Platform",
                "Plugin"
            ],
            path: "Tests/LoomTestKit"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                "Core",
                "LoomTestKit"
            ]
        ),
        .testTarget(
            name: "BridgeTests",
            dependencies: [
                "Bridge",
                "Core",
                "Plugin",
                "LoomTestKit"
            ]
        ),
        .testTarget(
            name: "PlatformTests",
            dependencies: [
                "Platform",
                "PlatformMacOS",
                "Core",
                "WebEngine",
                "LoomTestKit"
            ]
        ),
        .testTarget(
            name: "PluginTests",
            dependencies: [
                "Plugin",
                "Bridge",
                "Core",
                "Platform",
                "LoomTestKit"
            ]
        ),
        .testTarget(
            name: "WebEngineTests",
            dependencies: [
                "WebEngine",
                "Platform",
                "Core",
                "LoomTestKit"
            ]
        ),
        .testTarget(
            name: "LoomTests",
            dependencies: [
                "Loom",
                "Core",
                "Bridge",
                "Platform",
                "Plugin",
                "WebEngine",
                "LoomTestKit"
            ]
        )
    ]
)
