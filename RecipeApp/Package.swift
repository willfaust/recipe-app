// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "RecipeApp",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.1.0")
    ],
    targets: [
        .executableTarget(
            name: "RecipeApp",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXFast", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLinalg", package: "mlx-swift"),
                .product(name: "Transformers", package: "swift-transformers")
            ]
        )
    ]
)
