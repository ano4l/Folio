import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folio_mobile/services/word_pdf_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('converts DOCX paragraphs into a local PDF', () async {
    final directory = await Directory.systemTemp.createTemp('folio-word-test-');
    addTearDown(() => directory.delete(recursive: true));
    final archive =
        Archive()..addFile(
          ArchiveFile.string('word/document.xml', '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Funding summary</w:t></w:r></w:p>
    <w:p><w:r><w:t>Tuition award: R12 000</w:t></w:r></w:p>
  </w:body>
</w:document>
'''),
        );
    final source = File(
      '${directory.path}${Platform.pathSeparator}sample.docx',
    );
    await source.writeAsBytes(ZipEncoder().encode(archive));

    final path = await WordPdfConverter.convert(
      source.path,
      outputDirectory: directory,
    );
    final bytes = await File(path).readAsBytes();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('rejects files without readable Word content', () async {
    final directory = await Directory.systemTemp.createTemp(
      'folio-word-empty-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final archive =
        Archive()..addFile(ArchiveFile.string('unrelated.xml', '<root/>'));
    final source = File('${directory.path}${Platform.pathSeparator}empty.docx');
    await source.writeAsBytes(ZipEncoder().encode(archive));

    await expectLater(
      WordPdfConverter.convert(source.path),
      throwsA(isA<FormatException>()),
    );
  });
}
