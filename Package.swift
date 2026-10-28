// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "lucky65-media-keys",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "keydebug"),
        .testTarget(name: "keydebugTests", dependencies: ["keydebug"]),
    ],
    // The IOKit and CoreGraphics callbacks are plain C function pointers; v5 mode avoids strict-concurrency noise around them.
    swiftLanguageModes: [.v5]
)
