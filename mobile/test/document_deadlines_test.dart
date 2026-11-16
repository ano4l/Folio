import 'package:flutter_test/flutter_test.dart';
import 'package:folio_mobile/models/document.dart';
import 'package:folio_mobile/services/document_deadlines.dart';

void main() {
  test('proof of payment is one submission deadline rather than a duplicate payment event', () {
    const text = 'Payment deadline: 30 October 2026. Submit proof of payment by 2 November 2026.';
    const doc = Document(id: 'statement', title: 'Registration statement', type: 'Fee Statement',
      date: '', pages: 1, status: 'Ready', confidence: 97, summary: '', rawText: text,
      sourcePages: [SourcePage(1, text)], entities: [
        DocEntity(label: 'Payment deadline', value: '30 October 2026'),
        DocEntity(label: 'Submission deadline', value: '2 November 2026'),
      ]);
    final candidates = extractDocumentDeadlines([doc]);
    expect(candidates.length, 2);
    expect(candidates.map((candidate) => candidate.action).toSet(), {'Payment deadline', 'Submission deadline'});
    expect(candidates.map((candidate) => candidate.due).toSet(), {DateTime(2026, 10, 30), DateTime(2026, 11, 2)});
  });
}
