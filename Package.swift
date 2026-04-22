// swift-tools-version: 5.9
// Loom — macOS-native photo-wall app. See VISION.md.

import PackageDescription

let package = Package(
    name: "Loom",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Loom", targets: ["Loom"])
    ],
    targets: [
        .executableTarget(
            name: "Loom",
            dependencies: [
                "LoomCore",
                "LoomDesign",
                "LoomIndex",
                "LoomLayout",
                "LoomCompose",
                "LoomUI"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "LoomCore"
        ),
        .target(
            name: "LoomDesign",
            dependencies: ["LoomCore"]
        ),
        .target(
            name: "LoomIndex",
            dependencies: ["LoomCore"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "LoomLayout",
            dependencies: ["LoomCore"]
        ),
        .target(
            name: "LoomCompose",
            dependencies: ["LoomCore", "LoomIndex", "LoomLayout"]
        ),
        .target(
            name: "LoomUI",
            dependencies: [
                "LoomCore",
                "LoomDesign",
                "LoomIndex",
                "LoomLayout",
                "LoomCompose"
            ]
        ),
        .testTarget(
            name: "LoomCoreTests",
            dependencies: ["LoomCore"]
        ),
        .testTarget(
            name: "LoomLayoutTests",
            dependencies: ["LoomLayout"]
        )
    ]
)
