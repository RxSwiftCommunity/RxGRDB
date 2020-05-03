// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "RxGRDB",
    platforms: [
        .iOS("9.0"),
        .macOS("10.10"),
        .tvOS("9.0"),
        .watchOS("2.0"),
    ],
    products: [
        .library(name: "RxGRDB", targets: ["RxGRDB"]),
    ],
    dependencies: [
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "5.0.0-beta")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "5.0.1"))
    ],
    targets: [
        .target(
            name: "RxGRDB",
            dependencies: ["GRDB", "RxSwift"]),
        .testTarget(
            name: "RxGRDBTests",
            dependencies: [
                "GRDB",
                "RxGRDB", 
                .product(name: "RxBlocking", package: "RxSwift")])
    ],
    swiftLanguageVersions: [.v5]
)
