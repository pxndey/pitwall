// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Pitwall",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .executable(name: "Pitwall", targets: ["Pitwall"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Pitwall",
            dependencies: [],
            path: "Sources/Pitwall",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "PitwallTests",
            dependencies: ["Pitwall"],
            path: "Tests/PitwallTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
