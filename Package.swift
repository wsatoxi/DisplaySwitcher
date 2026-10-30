// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DisplaySwitcher",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DisplaySwitcher",
            path: "Sources/DisplaySwitcher",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
