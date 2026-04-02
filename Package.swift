// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MixMate",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MixMate",
            path: "Sources"
        )
    ]
)
