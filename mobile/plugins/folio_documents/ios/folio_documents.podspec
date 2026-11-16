Pod::Spec.new do |s|
  s.name = 'folio_documents'
  s.version = '1.0.0'
  s.summary = 'Folio document scanning, OCR and PDF tools.'
  s.description = 'On-device student document operations for Folio.'
  s.homepage = 'https://github.com/ano4l/Folio'
  s.author = 'Folio'
  s.license = { :type => 'Proprietary' }
  s.source = { :path => '.' }
  s.source_files = 'folio_documents/Sources/folio_documents/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
  s.frameworks = 'UIKit', 'AVFoundation', 'PDFKit', 'Vision', 'VisionKit', 'ImageIO'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
