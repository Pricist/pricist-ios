// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Pricist",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "Pricist",
            targets: ["Pricist"]
        ),
    ],
    targets: [
        .target(
            name: "Pricist",
            dependencies: [],
            path: "Sources/Pricist"
        ),
        .testTarget(
            name: "PricistTests",
            dependencies: ["Pricist"],
            path: "Tests/PricistTests"
        ),
    ]
)
