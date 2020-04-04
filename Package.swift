// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "RxGRDB",
    products: [
        .library(name: "RxGRDB", targets: ["RxGRDB"]),
    ],
    dependencies: [
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift.git", .branch("GRDB5")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "5.0.1"))
    ],
    targets: [
        .target(
            name: "RxGRDB",
            dependencies: ["GRDB", "RxSwift"],
            path: "RxGRDB"),
        .testTarget(
            name: "RxGRDBTests",
            dependencies: ["RxGRDB", "GRDB", "RxBlocking"],
            path: "Tests",
            exclude: ["CocoaPods"])
    ],
    swiftLanguageVersions: [.v5]
)
