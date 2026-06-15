// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ProwlKit",
    defaultLocalization: "en",
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
        .library(
            name: "ProwlGRPC",
            targets: ["ProwlGRPC"]
        ),
        .executable(
            name: "prowl",
            targets: ["ProwlCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "ProwlCore",
            linkerSettings: [
                .linkedLibrary("z"),
            ]
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
        .target(
            name: "ProwlGRPC",
            dependencies: [
                "ProwlCore",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
            ],
            swiftSettings: [
                .enableExperimentalFeature(
                    "AvailabilityMacro=gRPCSwift 2.0:macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0"
                ),
                .enableExperimentalFeature(
                    "AvailabilityMacro=gRPCSwift 2.3:macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0"
                ),
            ]
        ),
        .executableTarget(
            name: "ProwlCLI",
            dependencies: [
                "ProwlCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "ProwlTests",
            dependencies: ["ProwlKit", "ProwlUI"],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
    ]
)
