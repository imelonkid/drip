// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Drip",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Drip",
            path: "Sources/Drip",
            swiftSettings: [.unsafeFlags(["-Osize"])]
        )
    ]
)
