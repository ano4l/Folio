import '../models/document.dart';

/// A source-backed date or a date requiring review. No relative dates or
/// missing years are silently inferred from the current date.
class DocumentDeadlineCandidate {
  const DocumentDeadlineCandidate({
    required this.documentId,
    required this.title,
    required this.action,
    required this.dateText,
    required this.sourceText,
    required this.sourceKey,
    this.due,
    this.page,
  });
  final String documentId, title, action, dateText, sourceText, sourceKey;
  final DateTime? due;
  final int? page;
}

final _deadlineCue = RegExp(
  r'\b(deadline|due|closing\s+date|closes?|submit(?:ted)?\s+by|submission|pay(?:ment)?\s+by|last\s+(?:day|date)|no\s+later\s+than)\b',
  caseSensitive: false,
);
final _uncertain = RegExp(
  r'\b(example|sample|tentative|provisional|estimated|approximately|not\s+(?:due|a\s+deadline))\b',
  caseSensitive: false,
);
const _monthNames =
    r'January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec';
final _dateToken = RegExp(
  r'\b(?:\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/.]\d{1,2}[-/.]\d{4}|\d{1,2}(?:st|nd|rd|th)?\s+(?:' +
      _monthNames +
      r')(?:\s*,?\s*\d{4})?|(?:' +
      _monthNames +
      r')\s+\d{1,2}(?:st|nd|rd|th)?(?:\s*,?\s*\d{4})?)\b',
  caseSensitive: false,
);
const _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];

DateTime? parseDocumentDeadlineDate(String value) {
  final text = value.trim().toLowerCase().replaceAllMapped(
    RegExp(r'(\d)(st|nd|rd|th)\b'),
    (m) => m[1]!,
  );
  var match = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$').firstMatch(text);
  int? year, month, day;
  if (match != null) {
    year = int.parse(match[1]!);
    month = int.parse(match[2]!);
    day = int.parse(match[3]!);
  } else {
    match = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(text);
    if (match != null) {
      final first = int.parse(match[1]!), second = int.parse(match[2]!);
      // Only an unambiguous numeric order is safe to import automatically.
      if (first > 12 && second <= 12) {
        day = first;
        month = second;
      } else if (second > 12 && first <= 12) {
        month = first;
        day = second;
      } else if (first == second) {
        day = first;
        month = second;
      } else {
        return null;
      }
      year = int.parse(match[3]!);
    } else {
      match = RegExp(r'^(\d{1,2})\s+([a-z]+)\s*,?\s*(\d{4})$').firstMatch(text);
      if (match != null) {
        if (match[2]!.length < 3) return null;
        day = int.parse(match[1]!);
        month = _months.indexOf(match[2]!.substring(0, 3)) + 1;
        year = int.parse(match[3]!);
      } else {
        match = RegExp(
          r'^([a-z]+)\s+(\d{1,2})\s*,?\s*(\d{4})$',
        ).firstMatch(text);
        if (match == null || match[1]!.length < 3) return null;
        month = _months.indexOf(match[1]!.substring(0, 3)) + 1;
        day = int.parse(match[2]!);
        year = int.parse(match[3]!);
      }
    }
  }
  if (year < 1900 ||
      year > 2200 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31) {
    return null;
  }
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

String _kind(String text) {
  if (RegExp(
    r'\b(submit|submission|assignment|assessment)\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'Submission';
  }
  if (RegExp(
    r'\b(pay|payment|fee|fees|instalment|installment)\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'Payment';
  }
  if (RegExp(
    r'\b(application|apply|applications)\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'Application';
  }
  if (RegExp(
    r'\b(register|registration|enrolment|enrollment)\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'Registration';
  }
  return 'Document';
}

/// Runs in a background isolate over immutable document data.
List<DocumentDeadlineCandidate> extractDocumentDeadlines(
  List<Document> documents,
) {
  final output = <DocumentDeadlineCandidate>[];
  for (final doc in documents) {
    final candidates = <String, DocumentDeadlineCandidate>{};
    final sections =
        doc.sourcePages.isEmpty
            ? [SourcePage(0, doc.rawText)]
            : doc.sourcePages;
    final sourceDates =
        sections
            .expand((section) => _dateToken.allMatches(section.text))
            .map((m) => parseDocumentDeadlineDate(m.group(0)!))
            .whereType<DateTime>()
            .toSet();
    void add(String context, String action, {int? page, bool entity = false}) {
      if (!_deadlineCue.hasMatch(context)) return;
      final dates = _dateToken.allMatches(context).toList();
      for (var i = 0; i < dates.length; i++) {
        final token = dates[i];
        if (!entity) {
          final prefix = context.substring(
            i == 0 ? 0 : dates[i - 1].end,
            token.start,
          );
          if (!_deadlineCue.hasMatch(prefix) && dates.length != 1) continue;
        }
        final dateText = token.group(0)!;
        final parsedDate = parseDocumentDeadlineDate(dateText);
        final due =
            _uncertain.hasMatch(context) ||
                    (entity &&
                        (dates.length > 1 || !sourceDates.contains(parsedDate)))
                ? null
                : parsedDate;
        final kind = _kind(context);
        final dateKey = due?.toIso8601String() ?? dateText.toLowerCase();
        final key = '${doc.id}|$kind|$dateKey';
        if (due != null) {
          if (kind == 'Document' &&
              candidates.values.any(
                (c) => c.due == due && !c.sourceKey.contains('|Document|'),
              )) {
            continue;
          }
          if (kind != 'Document') {
            candidates.removeWhere(
              (_, c) => c.due == due && c.sourceKey.contains('|Document|'),
            );
          }
        }
        final excerptStart = (token.start - 160).clamp(0, context.length);
        final excerptEnd = (token.end + 160).clamp(0, context.length);
        candidates.putIfAbsent(
          key,
          () => DocumentDeadlineCandidate(
            documentId: doc.id,
            title: doc.title,
            action: entity ? action : '$kind deadline',
            dateText: dateText,
            sourceText: context.substring(excerptStart, excerptEnd).trim(),
            sourceKey: key,
            due: due,
            page: page,
          ),
        );
      }
    }

    for (final section in sections) {
      final lines = section.text.split(RegExp(r'[\n\r]+'));
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (!_deadlineCue.hasMatch(line)) continue;
        if (!_dateToken.hasMatch(line) && i + 1 < lines.length) {
          line += ' ${lines[i + 1]}';
        }
        // Isolate sentences so unrelated issue dates don't become due dates.
        for (final sentence in line.split(RegExp(r'(?<=[.!?;])\s+(?=[A-Z])'))) {
          add(sentence, '', page: section.number == 0 ? null : section.number);
        }
      }
    }
    for (final entity in doc.entities) {
      if (!_deadlineCue.hasMatch(entity.label)) continue;
      add('${entity.label}: ${entity.value}', entity.label, entity: true);
    }
    output.addAll(candidates.values);
  }
  return output;
}
