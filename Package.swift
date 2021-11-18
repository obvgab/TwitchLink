// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TwitchLink",
    products: [
        .library(
            name: "TwitchLink",
            targets: ["TwitchLink"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TwitchLink",
            dependencies: []),
    ]
)
