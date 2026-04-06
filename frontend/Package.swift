// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Pitwall",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .executable(name: "Pitwall", targets: ["Pitwall"]),
    ],
    targets: [
        .executableTarget(
            name: "Pitwall",
            path: "Sources/Pitwall"
        ),
        .testTarget(
            name: "PitwallTests",
            dependencies: ["Pitwall"],
            path: "Tests/PitwallTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
