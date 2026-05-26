// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DesktopNavigator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DesktopNavigator",
            path: "Sources/DesktopNavigator"
        )
    ]
)
