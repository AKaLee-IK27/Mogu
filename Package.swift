// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Drilbur",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Drilbur", targets: ["Drilbur"])
    ],
    targets: [
        .executableTarget(
            name: "Drilbur",
            path: "Sources"
        )
    ]
)
