// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StaticServer",
    products: [
        .executable(name: "static-server-cli", targets: ["StaticServerCLI"]),
        .library(name: "StaticServer", targets: ["StaticServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "StaticServer",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ]
        ),
        .target(
            name: "StaticServerCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "StaticServer",
            ]
        ),
        .testTarget(
            name: "StaticServerTests",
            dependencies: ["StaticServer"]
        ),
    ]
)
