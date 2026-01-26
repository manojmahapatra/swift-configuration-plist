// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-configuration-plist",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "ConfigurationPlist", targets: ["ConfigurationPlist"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-configuration", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ConfigurationPlist",
            dependencies: [
                .product(name: "Configuration", package: "swift-configuration"),
            ]
        ),
        .testTarget(
            name: "ConfigurationPlistTests",
            dependencies: ["ConfigurationPlist"]
        ),
    ]
)
