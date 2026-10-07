import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

/// Converts the readable paragraphs of a DOCX into a new PDF on the device.
/// Complex Word layout, embedded charts, headers and footnotes are not copied.
abstract final class WordPdfConverter {
  static Future<String> convert(
    String path, {
    Directory? outputDirectory,
  }) async {
    if (!path.toLowerCase().endsWith('.docx')) {
      throw const FormatException('Choose a DOCX Word document.');
    }
    final source = File(path);
    final size = await source.length();
    if (size < 1 || size > 20 * 1024 * 1024) {
      throw const FormatException('Choose a Word document under 20 MB.');
    }
    final package = ZipDecoder().decodeBytes(await source.readAsBytes());
    final entry = package.findFile('word/document.xml');
    if (entry == null || entry.size > 3 * 1024 * 1024) {
      throw const FormatException(
        'The Word document has no readable text or is too large.',
      );
    }
    final document = XmlDocument.parse(utf8.decode(entry.content));
    final body =
        document.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'body')
            .firstOrNull;
    if (body == null) {
      throw const FormatException('The Word document has no readable text.');
    }

    final paragraphs = <(String, bool)>[];
    var totalCharacters = 0;
    for (final paragraph in body.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'p',
    )) {
      final buffer = StringBuffer();
      var heading = false;
      for (final element in paragraph.descendants.whereType<XmlElement>()) {
        switch (element.name.local) {
          case 't':
            buffer.write(element.innerText);
          case 'tab':
            buffer.write('    ');
          case 'br':
            buffer.write('\n');
          case 'pStyle':
            final style =
                element.attributes
                    .where((attribute) => attribute.name.local == 'val')
                    .firstOrNull
                    ?.value;
            heading =
                style != null &&
                (style.toLowerCase().startsWith('heading') || style == 'Title');
        }
      }
      final text = buffer.toString().trim();
      if (text.isEmpty) continue;
      totalCharacters += text.length;
      if (paragraphs.length >= 2500 || totalCharacters > 180000) {
        throw const FormatException(
          'This Word document is too long for on-device conversion.',
        );
      }
      var firstChunk = true;
      for (final chunk in _chunks(text)) {
        paragraphs.add((chunk, heading && firstChunk));
        firstChunk = false;
      }
    }
    if (paragraphs.isEmpty) {
      throw const FormatException(
        'The Word document has no readable paragraphs.',
      );
    }

    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    final output = pw.Document(compress: true);
    output.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        maxPages: 100,
        build:
            (_) =>
                paragraphs
                    .map(
                      (entry) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Text(
                          entry.$1,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: entry.$2 ? 16 : 10.5,
                            lineSpacing: 3,
                          ),
                        ),
                      ),
                    )
                    .toList(),
      ),
    );
    final bytes = await output.save();
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException(
        'The converted PDF exceeds the 20 MB vault limit.',
      );
    }
    final directory = outputDirectory ?? await getTemporaryDirectory();
    final target = File(
      '${directory.path}${Platform.pathSeparator}folio-word-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  static Iterable<String> _chunks(String text) sync* {
    var remainder = text;
    while (remainder.length > 700) {
      var boundary = remainder.lastIndexOf(' ', 700);
      if (boundary < 350) boundary = 700;
      yield remainder.substring(0, boundary).trim();
      remainder = remainder.substring(boundary).trimLeft();
    }
    if (remainder.isNotEmpty) yield remainder;
  }
}
