// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TBB",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "TBBFoundation", targets: ["TBBFoundation"]),
        .library(name: "TBBAppShell", targets: ["TBBAppShell"])
    ],
    targets: [
        .target(name: "TBBFoundation"),
        .target(name: "TBBAppShell", dependencies: ["TBBFoundation"]),
        .testTarget(name: "TBBFoundationTests", dependencies: ["TBBFoundation"])
    ]
)
