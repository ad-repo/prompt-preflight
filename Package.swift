// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PromptPreflight",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PromptPreflight", targets: ["PromptPreflight"])
    ],
    targets: [
        .executableTarget(
            name: "PromptPreflight"
        ),
        .testTarget(
            name: "PromptPreflightTests",
            dependencies: ["PromptPreflight"]
        )
    ]
)
