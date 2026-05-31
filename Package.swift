// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MoleMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MoleMac", targets: ["MoleMac"])
    ],
    targets: [
        .executableTarget(
            name: "MoleMac",
            path: "Sources"
        )
    ]
)
