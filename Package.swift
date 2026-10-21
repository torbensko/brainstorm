// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Brainstorm",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Brainstorm", targets: ["BrainstormApp"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "BrainstormCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "BrainstormApp", dependencies: ["BrainstormCore"]),
        .testTarget(name: "BrainstormCoreTests", dependencies: ["BrainstormCore"])
    ]
)
