// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OrbitDock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "OrbitDock",
            targets: ["OrbitDock"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OrbitDock",
            dependencies: [],
            path: "Sources/OrbitDock"
        ),
        .testTarget(
            name: "OrbitDockTests",
            dependencies: ["OrbitDock"],
            path: "Tests/OrbitDockTests"
        )
    ]
)
