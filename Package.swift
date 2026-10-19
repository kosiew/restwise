// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Restwise",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure scheduling logic, no AppKit — easy to test.
        .target(name: "RestwiseCore"),
        .executableTarget(name: "Restwise", dependencies: ["RestwiseCore"]),
        .testTarget(name: "RestwiseCoreTests", dependencies: ["RestwiseCore"]),
    ]
)
