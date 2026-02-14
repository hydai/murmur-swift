// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MurmurKit",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "MurmurKit", targets: ["MurmurKit"]),
    ],
    targets: [
        .target(
            name: "MurmurKit",
            path: "Sources"
        ),
        .testTarget(
            name: "MurmurKitTests",
            dependencies: ["MurmurKit"],
            path: "Tests"
        ),
    ]
)
