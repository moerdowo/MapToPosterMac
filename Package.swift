// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MapToPosterMac",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MapToPosterMac",
            path: "Sources/MapToPosterMac"
        )
    ]
)
