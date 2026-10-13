// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YTMusic",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "YTMusic",
            path: "Sources/YTMusic",
            exclude: ["img"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
