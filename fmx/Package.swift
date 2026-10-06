// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "fmx",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "fmx", targets: ["fmx"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "fmx",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/fmx"
        )
    ]
)
