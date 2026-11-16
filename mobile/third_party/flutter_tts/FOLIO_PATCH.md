# Folio SwiftPM packaging

Upstream: https://pub.dev/packages/flutter_tts/versions/4.2.5
Version: 4.2.5. License retained in LICENSE.

Dart APIs and existing platform implementations are preserved. iOS Swift sources
are shared by the CocoaPods podspec and SwiftPM target. The SwiftPM-only public
type alias exposes the existing plugin registration name without its Objective-C
forwarder. The upstream Objective-C forwarder remains available to CocoaPods.
No global Pub cache files are changed.
