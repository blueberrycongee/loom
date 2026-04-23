// swift-tools-version: 5.9
// Loom — macOS-native photo-wall app. See VISION.md.

import PackageDescription

let package = Package(
    name: "Loom",
    defaultLocalization: "en",
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
            // Info.plist isn't copied as a bundle resource. Instead it's
            // embedded directly into the __TEXT,__info_plist section of the
            // executable by the linker (see linkerSettings below). This is
            // the supported way to ship a macOS CLI/executable built from
            // SwiftPM with a real Info.plist — otherwise `swift run` /
            // `swift build` fail because SwiftPM can't produce an .app
            // bundle to host a plist resource.
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Loom/Resources/Info.plist"
                ])
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
            resources: [
                .copy("Resources")
            ],
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
            dependencies: ["LoomCore", "LoomLayout"]
        ),
        .testTarget(
            name: "LoomComposeTests",
            dependencies: ["LoomCore", "LoomLayout", "LoomCompose"]
        )
    ]
)
