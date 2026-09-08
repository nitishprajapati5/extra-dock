// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MultiDock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MultiDock",
            targets: ["MultiDock"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MultiDock",
            dependencies: [],
            path: "Sources/MultiDock"
        ),
        .testTarget(
            name: "MultiDockTests",
            dependencies: ["MultiDock"],
            path: "Tests/MultiDockTests"
        )
    ]
)
