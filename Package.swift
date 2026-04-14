// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mac-click-floater",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mac-click-floater", targets: ["mac-click-floater"])
    ],
    targets: [
        .executableTarget(
            name: "mac-click-floater"
        )
    ]
)
