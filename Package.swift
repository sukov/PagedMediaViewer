// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "PagedMediaViewer",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(name: "PagedMediaViewer", targets: ["PagedMediaViewer"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "PagedMediaViewer", dependencies: [], path: "Source"),
        .testTarget(name: "PagedMediaViewerTests",
                    dependencies: ["PagedMediaViewer"],
                    path: "Example/PagedMediaViewerTests"),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
