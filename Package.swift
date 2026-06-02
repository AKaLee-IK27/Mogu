// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Mogu",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Mogu", targets: ["Mogu"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Mogu",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
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
