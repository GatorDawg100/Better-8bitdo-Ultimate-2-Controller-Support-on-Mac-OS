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
        .executableTarget(
            name: "ControllerTester",
            dependencies: ["EightBitDoKit"],
            path: "Sources/ControllerTester"
        ),
        .testTarget(
            name: "ControllerTesterTests",
            dependencies: ["ControllerTester", "EightBitDoKit"]
        ),
    ]
)
