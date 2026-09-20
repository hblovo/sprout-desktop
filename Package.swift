// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sprout",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Sprout", targets: ["SproutApp"])],
    targets: [
        .target(name: "SproutCore"),
        .executableTarget(name: "SproutApp", dependencies: ["SproutCore"]),
        .testTarget(name: "SproutCoreTests", dependencies: ["SproutCore"]),
        .testTarget(name: "SproutAppTests", dependencies: ["SproutApp", "SproutCore"])
    ],
    swiftLanguageModes: [.v5]
)
