// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MedReminder",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MedReminder",
            path: "Sources"
        )
    ]
)
