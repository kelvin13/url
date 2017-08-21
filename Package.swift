// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "URL",
    products: [
        .library(name: "URL", targets: ["URL"])
    ],
    targets: [
        .target(
            name: "URL",
            path: "sources/url"),
        .testTarget(
            name: "URLTests",
            dependencies: ["URL"],
            path: "tests/url"),
    ]
)
