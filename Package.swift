// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pin",
    platforms: [.macOS("15.2")],
    products: [.executable(name: "Pin", targets: ["Pin"])],
    targets: [
        .executableTarget(name: "Pin"),
        .testTarget(name: "PinTests", dependencies: ["Pin"]),
    ]
)
