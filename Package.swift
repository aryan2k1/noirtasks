// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NoirTasks",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NoirTasks",
            path: "Sources/NoirTasks"
        )
    ]
)
