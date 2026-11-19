// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpotClickerCore",
    platforms: [.macOS(.v13), .iOS("18.0")],
    products: [.library(name: "SpotClickerCore", targets: ["SpotClickerCore"])],
    targets: [
        .target(name: "SpotClickerCore", path: "SpotClicker/Core"),
        .testTarget(name: "SpotClickerCoreTests", dependencies: ["SpotClickerCore"], path: "Tests")
    ]
)

