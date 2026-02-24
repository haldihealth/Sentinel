// swift-tools-version: 5.9
// GPU-Enabled LLM Package
// This is a local fork of LLM.swift with GPU layer configuration exposed

import PackageDescription

let package = Package(
    name: "GPUEnabledLLM",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "GPUEnabledLLM", targets: ["GPUEnabledLLM"]),
    ],
    dependencies: [
        // Use the original LLM.swift which includes llama.cpp with Metal support
        .package(url: "https://github.com/eastriverlee/LLM.swift", from: "1.8.0"),
    ],
    targets: [
        .target(
            name: "GPUEnabledLLM",
            dependencies: [
                .product(name: "LLM", package: "LLM.swift"),
            ]
        ),
    ]
)
