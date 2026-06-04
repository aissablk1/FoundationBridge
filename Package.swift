// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FoundationBridge",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FoundationBridgeCore", targets: ["FoundationBridgeCore"]),
        .library(name: "FoundationBridgeSession", targets: ["FoundationBridgeSession"]),
        .library(name: "ProtocolConversion", targets: ["ProtocolConversion"]),
        .library(name: "FoundationModelsBackend", targets: ["FoundationModelsBackend"]),
        .library(name: "FoundationBridgeServer", targets: ["FoundationBridgeServer"]),
        .executable(name: "foundationbridge", targets: ["FoundationBridgeCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
    ],
    targets: [
        .target(name: "FoundationBridgeCore"),
        .testTarget(
            name: "FoundationBridgeCoreTests",
            dependencies: ["FoundationBridgeCore"]
        ),
        .target(
            name: "FoundationBridgeSession",
            dependencies: ["FoundationBridgeCore"]
        ),
        .testTarget(
            name: "FoundationBridgeSessionTests",
            dependencies: ["FoundationBridgeSession"]
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
        .target(
            name: "FoundationBridgeServer",
            dependencies: [
                "FoundationBridgeCore",
                "ProtocolConversion",
                "FoundationModelsBackend",
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
        .executableTarget(
            name: "FoundationBridgeCLI",
            dependencies: [
                "FoundationBridgeCore",
                "ProtocolConversion",
                "FoundationModelsBackend",
                "FoundationBridgeServer",
            ]
        ),
    ]
)
