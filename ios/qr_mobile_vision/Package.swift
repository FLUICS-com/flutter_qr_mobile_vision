// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "qr_mobile_vision",
    platforms: [.iOS("15.5")],
    products: [
        .library(name: "qr-mobile-vision", targets: ["qr_mobile_vision"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "qr_mobile_vision",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")]
        )
    ]
)
