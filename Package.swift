// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SwiftyPlayer",
    platforms: [
        .iOS(.v10),
    ],
    products: [
        .library(
            name: "SwiftyPlayer",
            targets: ["SwiftyPlayer"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pinterest/PINCache.git",
            from: "3.0.3"
        )
    ],
    targets: [
        .target(
            name: "SwiftyPlayer",
            path: "Sources"
        ),
    ]
)
