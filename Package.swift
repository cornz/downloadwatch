// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "downloadwatch",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "downloadwatch", targets: ["downloadwatch"])],
    targets: [
        .target(name: "DownloadWatchCore"),
        .executableTarget(name: "downloadwatch", dependencies: ["DownloadWatchCore"]),
        .testTarget(name: "DownloadWatchCoreTests", dependencies: ["DownloadWatchCore"])
    ]
)
