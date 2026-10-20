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
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.1"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.7.3"),
        .package(url: "https://github.com/Frizlab/FSEventsWrapper.git", from: "2.1.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
        .package(url: "https://github.com/inseven/diligence.git", from: "2.0.1"),
        .package(url: "https://github.com/inseven/glitter.git", from: "0.1.3"),
        .package(url: "https://github.com/inseven/interact.git", from: "3.10.7"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.17.0"),


    ],
    targets: [
        .target(
            name: "FoldersCore",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Diligence", package: "diligence"),
                .product(name: "FSEventsWrapper", package: "FSEventsWrapper"),
                .product(name: "Glitter", package: "glitter"),
                .product(name: "Interact", package: "interact"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Yams", package: "Yams"),
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
