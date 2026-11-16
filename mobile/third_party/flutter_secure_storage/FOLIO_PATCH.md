# Folio SwiftPM packaging

Upstream: https://pub.dev/packages/flutter_secure_storage/versions/9.2.4
Version: 9.2.4. License retained in LICENSE.

Dart APIs and existing platform implementations are preserved. iOS Swift sources
are shared by the CocoaPods podspec and SwiftPM target. The SwiftPM-only public
type alias exposes the existing plugin registration name without its Objective-C
forwarder. The upstream Objective-C forwarder remains available to CocoaPods.
No global Pub cache files are changed.
