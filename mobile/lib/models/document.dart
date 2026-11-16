import 'study.dart';

class DocEntity {
  final String label;
  final String value;
  const DocEntity({required this.label, required this.value});

  factory DocEntity.fromJson(Map<String, dynamic> j) =>
      DocEntity(label: j['label'] ?? '', value: j['value'] ?? '');

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

class Document {
  final String id;
  final String title;
  final String type;
  final String date;
  final int pages;
  final String status;
  final int confidence;
  final String summary;
  final List<DocEntity> entities;
  final String rawText;
  final List<SourcePage> sourcePages;

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
    this.sourcePages = const [],
  });

  factory Document.fromJson(Map<String, dynamic> j) => Document(
    id: '${j['id'] ?? ''}',
    title: j['title'] ?? '',
    type: j['type'] ?? '',
    date: j['date'] ?? '',
    pages: j['pages'] ?? 1,
    status: j['status'] ?? 'Awaiting processing',
    confidence: j['confidence'] ?? 0,
    summary: j['summary'] ?? '',
    entities:
        (j['entities'] as List? ?? [])
            .map((e) => DocEntity.fromJson(e))
            .toList(),
    rawText: j['rawText'] ?? '',
    sourcePages:
        (j['sourcePages'] as List? ?? [])
            .whereType<Map>()
            .where(
              (p) =>
                  p['page'] is num &&
                  (p['page'] as num) >= 1 &&
                  p['text'] is String,
            )
            .map(
              (p) =>
                  SourcePage((p['page'] as num).toInt(), '${p['text'] ?? ''}'),
            )
            .toList(),
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
    'sourcePages':
        sourcePages.map((p) => {'page': p.number, 'text': p.text}).toList(),
  };
}

class SourcePage {
  const SourcePage(this.number, this.text);
  final int number;
  final String text;
}

class Deadline {
  final int id;
  final String action;
  final String doc;
  final String due;
  final int _days;
  final String? documentId;
  final String severity;
  final String? sourceKey, sourceText;
  final int? sourcePage;
  bool completed;

  Deadline({
    required this.id,
    required this.action,
    required this.doc,
    required this.due,
    required int days,
    this.documentId,
    required this.severity,
    this.completed = false,
    this.sourceKey,
    this.sourceText,
    this.sourcePage,
  }) : _days = days;

  late final DateTime? dueDate = DateTime.tryParse(due);
  int get days {
    final date = dueDate;
    if (date == null) return _days;
    final now = DateTime.now();
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'doc': doc,
    'due': due,
    'days': days,
    'severity': severity,
    'completed': completed,
    'documentId': documentId,
    'sourceKey': sourceKey,
    'sourceText': sourceText,
    'sourcePage': sourcePage,
  };

  factory Deadline.fromJson(Map<String, dynamic> j) => Deadline(
    id: j['id'] ?? 0,
    action: j['action'] ?? '',
    doc: j['doc'] ?? '',
    due: j['due'] ?? '',
    days: j['days'] ?? 0,
    severity: j['severity'] ?? 'low',
    completed: j['completed'] ?? false,
    documentId: j['documentId'],
    sourceKey: j['sourceKey'],
    sourceText: j['sourceText'],
    sourcePage: j['sourcePage'],
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'actor': actor,
    'action': action,
    'detail': detail,
    'category': category,
  };

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
  final String id;
  final String role;
  final String text;
  final String? sourceDoc;
  final int? sourcePage;
  final List<Map<String, String>> sources;
  final int? complianceConfidence;
  final String? complianceLogic;
  final bool incomplete;
  final bool saved;
  final StudyQuiz? quiz;
  final QuizRequest? quizRequest;

  const ChatMessage({
    this.id = '',
    required this.role,
    required this.text,
    this.sourceDoc,
    this.sourcePage,
    this.sources = const [],
    this.complianceConfidence,
    this.complianceLogic,
    this.incomplete = false,
    this.saved = false,
    this.quiz,
    this.quizRequest,
  });

  ChatMessage copyWith({
    String? role,
    String? text,
    bool? incomplete,
    bool? saved,
    List<Map<String, String>>? sources,
    StudyQuiz? quiz,
  }) => ChatMessage(
    id: id,
    role: role ?? this.role,
    text: text ?? this.text,
    sources: sources ?? this.sources,
    incomplete: incomplete ?? this.incomplete,
    saved: saved ?? this.saved,
    quiz: quiz ?? this.quiz,
    quizRequest: quizRequest,
    sourceDoc: sourceDoc,
    sourcePage: sourcePage,
    complianceConfidence: complianceConfidence,
    complianceLogic: complianceLogic,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'text': text,
    'sources': sources,
    'incomplete': incomplete || role == 'streaming',
    'saved': saved,
    'sourceDoc': sourceDoc,
    'sourcePage': sourcePage,
    'complianceConfidence': complianceConfidence,
    'complianceLogic': complianceLogic,
    if (quiz != null) 'quiz': quiz!.toJson(),
    if (quizRequest != null) 'quizRequest': quizRequest!.toJson(),
  };
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] ?? '',
    role: j['role'] == 'streaming' ? 'assistant' : j['role'] ?? 'assistant',
    text: j['text'] ?? '',
    incomplete: j['incomplete'] == true,
    saved: j['saved'] == true,
    sourceDoc: j['sourceDoc'],
    sourcePage: j['sourcePage'],
    complianceConfidence: j['complianceConfidence'],
    complianceLogic: j['complianceLogic'],
    sources:
        (j['sources'] as List? ?? [])
            .whereType<Map>()
            .map((s) => s.map((k, v) => MapEntry(k.toString(), v.toString())))
            .toList(),
    quiz:
        j['quiz'] is Map
            ? StudyQuiz.fromJson(Map<String, dynamic>.from(j['quiz'] as Map))
            : null,
    quizRequest:
        j['quizRequest'] is Map
            ? QuizRequest.fromJson(
              Map<String, dynamic>.from(j['quizRequest'] as Map),
            )
            : null,
  );
}

class AuthUser {
  final String id;
  final String email;
  final String displayName;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        (json['id'] as String).isEmpty ||
        json['email'] is! String) {
      throw const FormatException('Invalid account response');
    }
    return AuthUser(
      id: json['id'],
      email: json['email'],
      displayName: '${json['displayName'] ?? ''}',
    );
  }
}
