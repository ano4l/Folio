// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "folio_documents",
    platforms: [.iOS("13.0")],
    products: [.library(name: "folio-documents", targets: ["folio_documents"])],
    targets: [
        .target(
            name: "folio_documents",
            linkerSettings: [
                .linkedFramework("UIKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("PDFKit"),
                .linkedFramework("Vision"),
                .linkedFramework("VisionKit"),
                .linkedFramework("ImageIO")
            ]
        )
    ]
)
