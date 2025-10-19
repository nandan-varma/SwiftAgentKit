// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftAgentKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "SwiftAgentKit", targets: ["SwiftAgentKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-School/AnyCodable.git", from: "0.6.0"),
        .package(url: "https://github.com/kevinhermawan/swift-json-schema.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(name: "SwiftAgentKit", dependencies: ["AnyCodable", .product(name: "JSONSchema", package: "swift-json-schema")]),
        .testTarget(name: "SwiftAgentKitTests", dependencies: ["SwiftAgentKit"])
    ]
)