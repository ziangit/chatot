// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "chatot",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ChatotCore", targets: ["ChatotCore"]),
        .executable(name: "chatot-cli", targets: ["chatot-cli"]),
        .executable(name: "Chatot", targets: ["Chatot"]),
        .executable(name: "chatot-tests", targets: ["chatot-tests"]),
    ],
    targets: [
        .target(
            name: "ChatotCore",
            resources: [.copy("Prompts")]
        ),
        .executableTarget(name: "chatot-cli", dependencies: ["ChatotCore"]),
        .executableTarget(name: "Chatot", dependencies: ["ChatotCore"]),
        .executableTarget(name: "chatot-tests", dependencies: ["ChatotCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
