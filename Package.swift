// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FoundationBridge",
    platforms: [.macOS(.v15)], // .v26 requis pour FoundationModelsBackend (gardé par disponibilité)
    products: [
        .library(name: "FoundationBridgeCore", targets: ["FoundationBridgeCore"]),
        .library(name: "ProtocolConversion", targets: ["ProtocolConversion"]),
        .library(name: "FoundationModelsBackend", targets: ["FoundationModelsBackend"]),
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
    ]
)
