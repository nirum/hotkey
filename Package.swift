// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Hotkey",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Hotkey", targets: ["Hotkey"]),
    ],
    targets: [
        .target(
            name: "HotkeyCore",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=minimal")]
        ),
        .executableTarget(
            name: "Hotkey",
            dependencies: ["HotkeyCore"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=minimal")]
        ),
        .testTarget(
            name: "HotkeyCoreTests",
            dependencies: ["HotkeyCore"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=minimal")]
        ),
    ]
)
