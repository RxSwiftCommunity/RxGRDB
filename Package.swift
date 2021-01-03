// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "RxGRDB",
    platforms: [
        .iOS("10.0"),
        .macOS("10.10"),
        .tvOS("9.0"),
        .watchOS("2.0"),
    ],
    products: [
        .library(name: "RxGRDB", targets: ["RxGRDB"]),
    ],
    dependencies: [
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.0.0"))
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
