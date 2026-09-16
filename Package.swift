// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ControllerTester",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EightBitDoKit",
            targets: ["EightBitDoKit"]
        ),
        .library(
            name: "DualSenseEmulationKit",
            targets: ["DualSenseEmulationKit"]
        ),
        .executable(
            name: "ControllerTester",
            targets: ["ControllerTester"]
        )
    ],
    targets: [
        .target(
            name: "EightBitDoKit",
            dependencies: [],
            path: "Sources/EightBitDoKit"
        ),
        .target(
            name: "DualSenseEmulationKit",
            dependencies: ["EightBitDoKit"],
            path: "Sources/DualSenseEmulationKit"
        ),
        .executableTarget(
            name: "ControllerTester",
            dependencies: ["EightBitDoKit", "DualSenseEmulationKit"],
            path: "Sources/ControllerTester"
        ),
        .testTarget(
            name: "ControllerTesterTests",
            dependencies: ["ControllerTester", "EightBitDoKit", "DualSenseEmulationKit"]
        ),
    ]
)
