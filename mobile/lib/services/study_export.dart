import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/study.dart';
import '../models/document.dart';

abstract final class StudyExport {
  static String markdown(
    StudySpace space,
    List<StudyNote> notes,
    List<StudyCard> cards,
  ) {
    final out = StringBuffer(
      '# ${space.name}\n\nExported from Folio. Check linked sources when revising.\n\n',
    );
    for (final note in notes) {
      out.writeln(
        '## ${note.title}\n\n${note.body}\n\nSource: ${note.documentTitle}${note.sourcePage == null ? '' : ' · page ${note.sourcePage}'}\n',
      );
    }
    if (cards.isNotEmpty) out.writeln('## Revision cards\n');
    for (final card in cards) {
      out.writeln(
        '### ${card.front}\n\n${card.back}\n\nSource: ${card.documentTitle}${card.sourcePage == null ? '' : ' · page ${card.sourcePage}'}\n',
      );
    }
    return out.toString();
  }

  static Future<String> textFile(String text, String extension) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/folio-export-${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await file.writeAsString(text, flush: true);
    return file.path;
  }

  static Future<String> pdf(String title, String text) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final doc = pw.Document(compress: true);
    final chunks = <String>[];
    var remaining = text;
    while (remaining.length > 600) {
      var i = remaining.lastIndexOf(' ', 600);
      if (i < 300) i = 600;
      chunks.add(remaining.substring(0, i));
      remaining = remaining.substring(i).trimLeft();
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 200,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header:
            (_) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Text(title, style: const pw.TextStyle(fontSize: 16)),
            ),
        footer:
            (context) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Folio · ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
        build:
            (_) =>
                chunks
                    .map(
                      (chunk) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Text(
                          chunk,
                          style: const pw.TextStyle(
                            fontSize: 10.5,
                            lineSpacing: 3,
                          ),
                        ),
                      ),
                    )
                    .toList(),
      ),
    );
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/folio-export-${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await doc.save(), flush: true);
    return file.path;
  }

  static String calendar(List<Deadline> deadlines, {DateTime? now}) {
    String date(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    String escape(String value) => value
        .replaceAll('\\', '\\\\')
        .replaceAll('\r', '')
        .replaceAll('\n', r'\n')
        .replaceAll(',', r'\,')
        .replaceAll(';', r'\;');
    final stamp =
        '${(now ?? DateTime.now())
            .toUtc()
            .toIso8601String()
            .replaceAll('-', '')
            .replaceAll(':', '')
            .split('.')
            .first}Z';
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Folio//Student Planner//EN',
      'CALSCALE:GREGORIAN',
    ];
    for (final task in deadlines.where(
      (d) => !d.completed && d.dueDate != null,
    )) {
      final due = task.dueDate!;
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:folio-${task.id}@folio.local',
        'DTSTAMP:$stamp',
        'DTSTART;VALUE=DATE:${date(due)}',
        'DTEND;VALUE=DATE:${date(DateTime(due.year, due.month, due.day + 1))}',
        'SUMMARY:${escape(task.action)}',
        'DESCRIPTION:${escape('Folio task · ${task.doc}')}',
        'END:VEVENT',
      ]);
    }
    lines.add('END:VCALENDAR');
    // Fold by UTF-8 byte length so non-ASCII course names remain valid in calendar apps.
    return '${lines
            .map((line) {
              final parts = <String>[];
              var current = '';
              var bytes = 0;
              for (final rune in line.runes) {
                final char = String.fromCharCode(rune);
                final length =
                    rune < 128
                        ? 1
                        : rune < 2048
                        ? 2
                        : rune < 65536
                        ? 3
                        : 4;
                if (bytes + length > 73) {
                  parts.add(current);
                  current = ' ';
                  bytes = 1;
                }
                current += char;
                bytes += length;
              }
              parts.add(current);
              return parts.join('\r\n');
            })
            .join('\r\n')}\r\n';
  }
}
