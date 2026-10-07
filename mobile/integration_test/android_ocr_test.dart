import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:folio_mobile/services/document_scanner.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native adapter recognises an imported image with on-device OCR',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Folio OCR verification'))),
        ),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
      final paragraph =
          (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 48))
                ..pushStyle(ui.TextStyle(color: Colors.black))
                ..addText(
                  'BURSARY RENEWAL\nSubmit documents by 30 September 2026.',
                ))
              .build()
            ..layout(const ui.ParagraphConstraints(width: 1100));
      canvas.drawParagraph(paragraph, const Offset(40, 50));
      final picture = recorder.endRecording();
      final image = await picture.toImage(1200, 500);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = await Directory.systemTemp.createTemp(
        'folio-ocr-test-',
      );
      final file = File('${directory.path}/fixture.png');
      try {
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        final pages = await DocumentScanner.extract(file.path);
        expect(pages.single['page'], 1);
        expect(
          pages.single['text'].toString().toLowerCase(),
          contains('bursary renewal'),
        );
        expect(pages.single['text'], contains('30 September 2026'));
      } finally {
        image.dispose();
        picture.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
