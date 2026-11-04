// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "SettingsKitExample",
    platforms: [.macOS(.v26)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "SettingsKitExample",
            dependencies: [.product(name: "SettingsKit", package: "SettingsKit")],
            swiftSettings: [.enableUpcomingFeature("ApproachableConcurrency")]
        ),
    ]
)
