import Flutter
import UIKit
import AVFoundation
import PDFKit
import Vision
import VisionKit
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var documents: FolioDocuments?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    documents = FolioDocuments(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// The iOS adapter for the same channel and page contract used by Android.
/// Keep all product UI in Dart; only camera capture and OCR belong here.
private final class FolioDocuments: NSObject, VNDocumentCameraViewControllerDelegate {
  private let channel: FlutterMethodChannel
  private let worker = DispatchQueue(label: "folio.document-reader", qos: .userInitiated)
  private var pendingScan: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "folio/documents", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "scan": self.scan(result)
      case "mergePdf", "imagesToPdf", "extractPages":
        self.worker.async {
          do {
            let path = try self.makePdf(call)
            DispatchQueue.main.async { result(path) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "DOCUMENT_TOOL_FAILED", message: error.localizedDescription, details: nil))
            }
          }
        }
      case "extract":
        guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_FILE", message: "Choose a file first.", details: nil))
          return
        }
        self.worker.async {
          do {
            let pages = try self.extract(path)
            DispatchQueue.main.async { result(pages) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "OCR_UNAVAILABLE", message: "On-device text reading could not finish. The original file can still be uploaded for review.", details: nil))
            }
          }
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func scan(_ result: @escaping FlutterResult) {
    guard pendingScan == nil else {
      result(FlutterError(code: "BUSY", message: "A scan is already open.", details: nil))
      return
    }
    guard VNDocumentCameraViewController.isSupported else {
      result(FlutterError(code: "SCANNER_UNAVAILABLE", message: "Scanner unavailable on this device. Import a file instead.", details: nil))
      return
    }
    pendingScan = result
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: presentScanner()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
        DispatchQueue.main.async {
          if allowed { self?.presentScanner() } else { self?.cameraDenied() }
        }
      }
    default: cameraDenied()
    }
  }

  private func cameraDenied() {
    finish(FlutterError(code: "CAMERA_DENIED", message: "Allow camera access in Settings to scan, or choose a file instead.", details: nil))
  }

  private func presentScanner() {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    guard let window = scenes.first(where: { $0.activationState == .foregroundActive })?.windows.first(where: { $0.isKeyWindow }),
          var presenter = window.rootViewController else {
      finish(FlutterError(code: "SCANNER_UNAVAILABLE", message: "Return to Folio and try again.", details: nil))
      return
    }
    while let presented = presenter.presentedViewController { presenter = presented }
    let scanner = VNDocumentCameraViewController()
    scanner.delegate = self
    scanner.modalPresentationStyle = .fullScreen
    presenter.present(scanner, animated: true)
  }

  private func finish(_ value: Any?) {
    let result = pendingScan
    pendingScan = nil
    result?(value)
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true) { self.finish(nil) }
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    controller.dismiss(animated: true) {
      self.finish(FlutterError(code: "SCAN_FAILED", message: "Scan could not finish. Try again or import a file.", details: nil))
    }
  }

  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    controller.dismiss(animated: true) {
      guard (1...20).contains(scan.pageCount) else {
        self.finish(FlutterError(code: "PAGE_LIMIT", message: "Scan up to 20 pages at a time. Split this document and try again.", details: nil))
        return
      }
      self.worker.async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("folio-scan-\(UUID().uuidString).pdf")
        do {
          let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
          try renderer.writePDF(to: url) { context in
            for index in 0..<scan.pageCount {
              autoreleasepool {
                let image = scan.imageOfPage(at: index)
                let scale = 612 / max(image.size.width, image.size.height)
                let bounds = CGRect(origin: .zero, size: CGSize(width: image.size.width * scale, height: image.size.height * scale))
                context.beginPage(withBounds: bounds, pageInfo: [:])
                image.draw(in: bounds)
              }
            }
          }
          try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
          let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
          guard size > 0 && size <= 20 * 1024 * 1024 else { throw ReaderError.invalidFile }
          DispatchQueue.main.async { self.finish(url.path) }
        } catch {
          try? FileManager.default.removeItem(at: url)
          DispatchQueue.main.async {
            self.finish(FlutterError(code: "SCAN_SAVE", message: "Scan could not be saved within the 20 MB limit. Try fewer pages.", details: nil))
          }
        }
      }
    }
  }

  private enum ReaderError: LocalizedError {
    case invalidFile, tooManyPages, invalidPages, tooLarge, unsupportedFile
    var errorDescription: String? {
      switch self {
      case .invalidFile: return "Choose a valid file stored on this device."
      case .tooManyPages: return "Select no more than 100 PDF pages at a time."
      case .invalidPages: return "Enter page numbers such as 1-3,5."
      case .tooLarge: return "The finished PDF exceeds the 20 MB vault limit. Try fewer pages."
      case .unsupportedFile: return "This file type cannot be converted on this device."
      }
    }
  }

  private func localFile(_ path: String, extensions: Set<String>) throws -> URL {
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
    let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path + "/"
    guard url.path.hasPrefix(home), extensions.contains(url.pathExtension.lowercased()) else { throw ReaderError.unsupportedFile }
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size > 0, size <= 20 * 1024 * 1024 else { throw ReaderError.invalidFile }
    return url
  }

  private func outputUrl() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("folio-tool-\(UUID().uuidString).pdf")
  }

  private func checkedOutput(_ url: URL) throws -> String {
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size > 0, size <= 20 * 1024 * 1024 else {
      try? FileManager.default.removeItem(at: url)
      throw ReaderError.tooLarge
    }
    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    return url.path
  }

  private func makePdf(_ call: FlutterMethodCall) throws -> String {
    guard let args = call.arguments as? [String: Any] else { throw ReaderError.invalidFile }
    switch call.method {
    case "mergePdf":
      guard let paths = args["paths"] as? [String], (2...20).contains(paths.count) else { throw ReaderError.invalidFile }
      let merged = PDFDocument()
      for path in paths {
        let url = try localFile(path, extensions: ["pdf"])
        guard let input = PDFDocument(url: url), !input.isLocked, input.pageCount > 0 else { throw ReaderError.invalidFile }
        guard merged.pageCount + input.pageCount <= 100 else { throw ReaderError.tooManyPages }
        for index in 0..<input.pageCount {
          guard let page = input.page(at: index)?.copy() as? PDFPage else { throw ReaderError.invalidFile }
          merged.insert(page, at: merged.pageCount)
        }
      }
      let url = outputUrl()
      guard merged.write(to: url) else { throw ReaderError.invalidFile }
      return try checkedOutput(url)
    case "extractPages":
      guard let path = args["path"] as? String, let spec = args["pages"] as? String else { throw ReaderError.invalidPages }
      let url = try localFile(path, extensions: ["pdf"])
      guard let source = PDFDocument(url: url), !source.isLocked, source.pageCount > 0 else { throw ReaderError.invalidFile }
      var indexes: [Int] = []
      for token in spec.split(separator: ",", omittingEmptySubsequences: false) {
        let bounds = token.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
        guard (1...2).contains(bounds.count), let start = Int(bounds[0]), start > 0 else { throw ReaderError.invalidPages }
        let end = bounds.count == 2 ? Int(bounds[1]) : start
        guard let end, end >= start, end <= source.pageCount else { throw ReaderError.invalidPages }
        for page in start...end where !indexes.contains(page - 1) { indexes.append(page - 1) }
        guard indexes.count <= 100 else { throw ReaderError.tooManyPages }
      }
      guard !indexes.isEmpty else { throw ReaderError.invalidPages }
      let output = PDFDocument()
      for index in indexes {
        guard let page = source.page(at: index)?.copy() as? PDFPage else { throw ReaderError.invalidFile }
        output.insert(page, at: output.pageCount)
      }
      let result = outputUrl()
      guard output.write(to: result) else { throw ReaderError.invalidFile }
      return try checkedOutput(result)
    case "imagesToPdf":
      guard let paths = args["paths"] as? [String], (1...20).contains(paths.count) else { throw ReaderError.invalidFile }
      let urls = try paths.map { try localFile($0, extensions: ["jpg", "jpeg", "png", "heic"]) }
      let result = outputUrl()
      let page = CGRect(x: 0, y: 0, width: 612, height: 792)
      let renderer = UIGraphicsPDFRenderer(bounds: page)
      var invalidImage = false
      try renderer.writePDF(to: result) { context in
        for url in urls {
          guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 2500
                ] as CFDictionary) else { invalidImage = true; return }
          let bounds = CGRect(x: 24, y: 24, width: 564, height: 744)
          let scale = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
          let fitted = CGRect(x: bounds.midX - CGFloat(image.width) * scale / 2,
                              y: bounds.midY - CGFloat(image.height) * scale / 2,
                              width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
          context.beginPage()
          UIImage(cgImage: image).draw(in: fitted)
        }
      }
      if invalidImage {
        try? FileManager.default.removeItem(at: result)
        throw ReaderError.invalidFile
      }
      return try checkedOutput(result)
    default: throw ReaderError.unsupportedFile
    }
  }

  private func recognize(_ image: CGImage) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
  }

  private func extract(_ path: String) throws -> [[String: Any]] {
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
    let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path + "/"
    guard url.path.hasPrefix(home) else { throw ReaderError.invalidFile }
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size > 0 && size <= 20 * 1024 * 1024 else { throw ReaderError.invalidFile }
    if url.pathExtension.lowercased() == "pdf" {
      guard let pdf = PDFDocument(url: url), !pdf.isLocked, (1...20).contains(pdf.pageCount) else { throw ReaderError.invalidFile }
      return try (0..<pdf.pageCount).map { index in
        try autoreleasepool {
          guard let page = pdf.page(at: index) else { throw ReaderError.invalidFile }
          let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          if !text.isEmpty { return ["page": index + 1, "text": text] }
          let bounds = page.bounds(for: .mediaBox)
          guard bounds.width > 0, bounds.height > 0 else { throw ReaderError.invalidFile }
          let scale = 2000 / max(bounds.width, bounds.height)
          let format = UIGraphicsImageRendererFormat()
          format.scale = 1
          format.opaque = true
          let targetSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
          let image = UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            context.cgContext.translateBy(x: 0, y: bounds.height * scale)
            context.cgContext.scaleBy(x: scale, y: -scale)
            context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
            page.draw(with: .mediaBox, to: context.cgContext)
          }
          guard let cgImage = image.cgImage else { throw ReaderError.invalidFile }
          return ["page": index + 1, "text": try recognize(cgImage)]
        }
      }
    }
    // Downsample and apply EXIF orientation before recognizing camera images.
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2000
          ] as CFDictionary) else { throw ReaderError.invalidFile }
    return [["page": 1, "text": try recognize(image)]]
  }
}
