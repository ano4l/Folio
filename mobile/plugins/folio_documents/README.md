# Folio documents

The iOS implementation of the existing `folio/documents` channel: camera scan,
PDF/image text extraction, merge, images to PDF, page extraction and rotation.

The same Swift source is built by Swift Package Manager (xcross) or CocoaPods
(standard Flutter/Xcode). Registration retains the native handler using
`FlutterPluginRegistrar.publish` so the method channel survives registration.

Android continues to use the existing application-native implementation.
