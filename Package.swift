// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XProject",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "X-project", targets: ["XProject"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "XProject",
            dependencies: [],
            path: "Sources/XProject"
        ),
        .testTarget(
            name: "XProjectTests",
            dependencies: ["XProject"],
            path: "Tests/XProjectTests"
        )
    ]
)
