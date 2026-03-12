// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WhisperCppRealtimeMacApp",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "WhisperCppRealtimeMacApp",
            targets: ["WhisperCppRealtimeMacApp"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "WhisperCppRealtimeMacApp"
        ),
    ]
)
