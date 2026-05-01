// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Hotkey",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Hotkey", targets: ["Hotkey"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Hotkey",
            dependencies: ["TOMLKit"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=minimal")]
        ),
    ]
)
