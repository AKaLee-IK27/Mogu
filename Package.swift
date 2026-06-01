// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Mogu",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Mogu", targets: ["Mogu"])
    ],
    targets: [
        .executableTarget(
            name: "Mogu",
            path: "Sources"
        ),
        .testTarget(
            name: "MoguTests",
            dependencies: ["Mogu"],
            path: "Tests/MoguTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
