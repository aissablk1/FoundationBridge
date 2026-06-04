// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FoundationBridge",
    // Universal : le binaire cible Apple Silicon (arm64) ET Intel/Rosetta (x86_64).
    // FoundationModelsBackend reste gardé par disponibilité (macOS 26 + device éligible).
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FoundationBridgeCore", targets: ["FoundationBridgeCore"]),
        .library(name: "ProtocolConversion", targets: ["ProtocolConversion"]),
        .library(name: "FoundationModelsBackend", targets: ["FoundationModelsBackend"]),
        .executable(name: "foundationbridge", targets: ["FoundationBridgeCLI"]),
    ],
    targets: [
        .target(name: "FoundationBridgeCore"),
        .testTarget(
            name: "FoundationBridgeCoreTests",
            dependencies: ["FoundationBridgeCore"]
        ),
        .target(
            name: "ProtocolConversion",
            dependencies: ["FoundationBridgeCore"]
        ),
        .testTarget(
            name: "ProtocolConversionTests",
            dependencies: ["ProtocolConversion"]
        ),
        .target(
            name: "FoundationModelsBackend",
            dependencies: ["FoundationBridgeCore"]
        ),
        .executableTarget(
            name: "FoundationBridgeCLI",
            dependencies: ["FoundationBridgeCore", "ProtocolConversion", "FoundationModelsBackend"]
        ),
    ]
)
