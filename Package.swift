// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PagedMediaViewer",
    defaultLocalization: "en",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "PagedMediaViewer",
            targets: ["PagedMediaViewer"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PagedMediaViewer",
            dependencies: [],
            path: "Source"
        )
    ]
)
