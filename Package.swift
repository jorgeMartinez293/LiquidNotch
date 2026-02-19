// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiquidNotch",
    platforms: [
        .macOS(.v13)
    ],

    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "LiquidNotch",
            dependencies: [
            ],
            path: "Sources/LiquidNotch"
        ),
    ]
)
