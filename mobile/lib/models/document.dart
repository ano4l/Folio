class DocEntity {
  final String label;
  final String value;
  const DocEntity({required this.label, required this.value});

  factory DocEntity.fromJson(Map<String, dynamic> j) =>
      DocEntity(label: j['label'] ?? '', value: j['value'] ?? '');

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

class Document {
  final int id;
  final String title;
  final String type;
  final String date;
  final int pages;
  final String status;
  final int confidence;
  final String summary;
  final List<DocEntity> entities;
  final String rawText;

  const Document({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.pages,
    required this.status,
    required this.confidence,
    required this.summary,
    required this.entities,
    required this.rawText,
  });

  factory Document.fromJson(Map<String, dynamic> j) => Document(
        id: j['id'] ?? 0,
        title: j['title'] ?? '',
        type: j['type'] ?? '',
        date: j['date'] ?? '',
        pages: j['pages'] ?? 1,
        status: j['status'] ?? 'Ready',
        confidence: j['confidence'] ?? 90,
        summary: j['summary'] ?? '',
        entities: (j['entities'] as List? ?? [])
            .map((e) => DocEntity.fromJson(e))
            .toList(),
        rawText: j['rawText'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'date': date,
        'pages': pages,
        'status': status,
        'confidence': confidence,
        'summary': summary,
        'entities': entities.map((e) => e.toJson()).toList(),
        'rawText': rawText,
      };
}

class Deadline {
  final int id;
  final String action;
  final String doc;
  final String due;
  final int days;
  final String severity;
  bool completed;

  Deadline({
    required this.id,
    required this.action,
    required this.doc,
    required this.due,
    required this.days,
    required this.severity,
    this.completed = false,
  });

  factory Deadline.fromJson(Map<String, dynamic> j) => Deadline(
        id: j['id'] ?? 0,
        action: j['action'] ?? '',
        doc: j['doc'] ?? '',
        due: j['due'] ?? '',
        days: j['days'] ?? 0,
        severity: j['severity'] ?? 'low',
        completed: j['completed'] ?? false,
      );
}

class AuditEntry {
  final int id;
  final String time;
  final String actor;
  final String action;
  final String detail;
  final String category;

  const AuditEntry({
    required this.id,
    required this.time,
    required this.actor,
    required this.action,
    required this.detail,
    required this.category,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: j['id'] ?? 0,
        time: j['time'] ?? '',
        actor: j['actor'] ?? '',
        action: j['action'] ?? '',
        detail: j['detail'] ?? '',
        category: j['category'] ?? 'Access',
      );
}

class ChatMessage {
  final String role;
  final String text;
  final String? sourceDoc;
  final int? sourcePage;
  final List<Map<String, String>> sources;

  const ChatMessage({
    required this.role,
    required this.text,
    this.sourceDoc,
    this.sourcePage,
    this.sources = const [],
  });
}
