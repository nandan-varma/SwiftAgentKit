// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftAgentKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "SwiftAgentKit", targets: ["SwiftAgentKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/Flight-School/AnyCodable.git", from: "0.6.0")
    ],
    targets: [
        .target(name: "SwiftAgentKit", dependencies: ["AnyCodable"]),
        .testTarget(name: "SwiftAgentKitTests", dependencies: ["SwiftAgentKit"])
    ]
)