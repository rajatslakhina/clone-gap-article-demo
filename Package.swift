// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CloneGap",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CloneGap", targets: ["CloneGap"])
    ],
    targets: [
        .target(name: "CloneGap"),
        .testTarget(name: "CloneGapTests", dependencies: ["CloneGap"])
    ]
)
