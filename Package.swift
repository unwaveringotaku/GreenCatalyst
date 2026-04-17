// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GreenCatalyst",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "GreenCatalystApp", targets: ["GreenCatalystApp"]),
        .library(name: "GreenCatalystWatch", targets: ["GreenCatalystWatch"]),
        .library(name: "GreenCatalystWidgets", targets: ["GreenCatalystWidgets"]),
    ],
    dependencies: [],
    targets: [
        // iOS App
        .target(
            name: "GreenCatalystApp",
            dependencies: [],
            path: "Sources/GreenCatalystApp",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        // watchOS Companion App
        .target(
            name: "GreenCatalystWatch",
            dependencies: ["GreenCatalystApp"],
            path: "Sources/GreenCatalystWatch"
        ),
        // WidgetKit Extension
        .target(
            name: "GreenCatalystWidgets",
            dependencies: ["GreenCatalystApp"],
            path: "Sources/GreenCatalystWidgets"
        ),
        // Tests
        .testTarget(
            name: "GreenCatalystTests",
            dependencies: ["GreenCatalystApp"],
            path: "Tests/GreenCatalystTests"
        ),
    ]
)
