// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "RFBCore",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "RFBCore",
            targets: ["RFBCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RFBCore",
            dependencies: [],
            path: "Sources/RFBCore"
        ),
        .testTarget(
            name: "RFBCoreTests",
            dependencies: ["RFBCore"],
            path: "Tests/RFBCoreTests"
        ),
    ]
)
