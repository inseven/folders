// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "FoldersCore",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "FoldersCore",
            targets: ["FoldersCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/inseven/diligence.git", from: "2.0.1"),
        .package(url: "https://github.com/inseven/glitter.git", from: "0.1.3"),
        .package(url: "https://github.com/inseven/interact.git", from: "3.10.7"),
    ],
    targets: [
        .target(
            name: "FoldersCore",
            dependencies: [
                .product(name: "Diligence", package: "diligence"),
                .product(name: "Glitter", package: "glitter"),
                .product(name: "Interact", package: "interact"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "FoldersCoreTests",
            dependencies: ["FoldersCore"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
