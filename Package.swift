// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftAgentKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "SwiftAgentKit", targets: ["SwiftAgentKit"])
    ],
    dependencies: [],
    targets: [
        .target(name: "SwiftAgentKit"),
        .testTarget(name: "SwiftAgentKitTests", dependencies: ["SwiftAgentKit"])
    ]
)