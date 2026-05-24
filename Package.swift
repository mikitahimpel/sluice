// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SluiceCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SluiceCore", targets: ["SluiceCore"]),
    ],
    targets: [
        .target(name: "SluiceCore"),
        .testTarget(name: "SluiceCoreTests", dependencies: ["SluiceCore"]),
    ]
)
