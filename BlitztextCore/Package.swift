// swift-tools-version: 5.10
import PackageDescription

// BlitztextCore holds the platform-agnostic core of Blitztext (no AppKit/AVFoundation),
// so it can be unit-tested in isolation and reused by a future iOS app.
let package = Package(
    name: "BlitztextCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "BlitztextCore", targets: ["BlitztextCore"]),
    ],
    targets: [
        .target(name: "BlitztextCore"),
        .testTarget(name: "BlitztextCoreTests", dependencies: ["BlitztextCore"]),
    ]
)
