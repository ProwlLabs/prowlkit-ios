// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ProwlKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "ProwlKit",
            targets: ["ProwlKit"]
        ),
        .library(
            name: "ProwlCore",
            targets: ["ProwlCore"]
        ),
        .library(
            name: "ProwlUI",
            targets: ["ProwlUI"]
        ),
    ],
    targets: [
        .target(
            name: "ProwlCore"
        ),
        .target(
            name: "ProwlUI",
            dependencies: ["ProwlCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "ProwlKit",
            dependencies: ["ProwlCore", "ProwlUI"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ProwlTests",
            dependencies: ["ProwlKit"]
        ),
    ]
)
