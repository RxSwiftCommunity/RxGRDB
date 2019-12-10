// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "RxGRDB",
    products: [
        .library(name: "RxGRDB", targets: ["RxGRDB"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "4.1.0")),
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
