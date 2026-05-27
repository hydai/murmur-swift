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
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MurmurKit",
            dependencies: [
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "MurmurKitTests",
            dependencies: ["MurmurKit"],
            path: "Tests"
        ),
    ]
)
