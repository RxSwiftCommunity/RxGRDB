// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "RxGRDB",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    products: [
        .library(name: "RxGRDB", targets: ["RxGRDB"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "7.1.0")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.0.0"))
    ],
    targets: [
        .target(
            name: "RxGRDB",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "RxSwift", package: "RxSwift"),
            ]),
        .testTarget(
            name: "RxGRDBTests",
            dependencies: [
                "RxGRDB",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "RxBlocking", package: "RxSwift"),
            ])
    ],
    swiftLanguageVersions: [.v5]
)
