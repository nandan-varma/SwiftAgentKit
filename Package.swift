// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftAgentKit",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "SwiftAgentKit", targets: ["SwiftAgentKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0"),
        .package(url: "https://github.com/kevinhermawan/swift-json-schema.git", from: "2.0.1")
    ],
    targets: [
        .target(name: "SwiftAgentKit", dependencies: ["SwiftyJSON", .product(name: "JSONSchema", package: "swift-json-schema")]),
        .testTarget(name: "SwiftAgentKitTests", dependencies: ["SwiftAgentKit"])
    ]
)