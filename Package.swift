// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnyGifClaudePet",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AnyGifClaudePet",
            path: "Sources/AnyGifClaudePet"
        )
    ]
)
