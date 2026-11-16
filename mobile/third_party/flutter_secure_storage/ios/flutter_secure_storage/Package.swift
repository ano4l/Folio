// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_secure_storage",
    platforms: [.iOS("13.0")],
    products: [.library(name: "flutter-secure-storage", targets: ["flutter_secure_storage"])],
    targets: [
        .target(
            name: "flutter_secure_storage",
            resources: [.process("PrivacyInfo.xcprivacy")],
            linkerSettings: [.linkedFramework("Security"), .linkedFramework("UIKit")]
        )
    ]
)
