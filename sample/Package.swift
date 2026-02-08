// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LoomSample",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .target(
            name: "LoomSampleLib",
            dependencies: [
                .product(name: "LoomCore", package: "Loom"),
                .product(name: "LoomPlugin", package: "Loom")
            ]
        ),
        .executableTarget(
            name: "LoomSample",
            dependencies: [
                "LoomSampleLib",
                .product(name: "Loom", package: "Loom")
            ],
            resources: [.copy("Resources/web")]
        ),
        .testTarget(
            name: "LoomSampleTests",
            dependencies: [
                "LoomSampleLib",
                .product(name: "LoomCore", package: "Loom"),
                .product(name: "LoomPlugin", package: "Loom")
            ]
        )
    ]
)
