// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OCRReader",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "OCRReader", targets: ["OCRReader"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OCRReader",
            path: "Sources/OCRReader",
            resources: [
                .copy("Resources/Reduce-File-Size.qfilter")
            ]
        )
    ]
)
