// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Brainstorm",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Brainstorm", targets: ["BrainstormApp"])],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "BrainstormCore", dependencies: ["CSQLite"]),
        .executableTarget(
            name: "BrainstormApp",
            dependencies: ["BrainstormCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "BrainstormCoreTests", dependencies: ["BrainstormCore"]),
        .testTarget(name: "BrainstormAppTests", dependencies: ["BrainstormApp", "BrainstormCore"])
    ]
)
