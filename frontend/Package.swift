// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PitCrew",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .executable(name: "PitCrew", targets: ["PitCrew"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PitCrew",
            dependencies: [],
            path: "Sources/PitCrew",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "PitCrewTests",
            dependencies: ["PitCrew"],
            path: "Tests/PitCrewTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
