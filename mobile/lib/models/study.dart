class QuizRequest {
  const QuizRequest({
    this.count = 5,
    this.difficulty = 'standard',
    this.focus = '',
  });
  final int count;
  final String difficulty;
  final String focus;

  Map<String, dynamic> toJson() => {
    'count': count,
    'difficulty': difficulty,
    'focus': focus,
  };
  factory QuizRequest.fromJson(Map<String, dynamic> json) => QuizRequest(
    count:
        json['count'] is int && [3, 5, 8].contains(json['count'])
            ? json['count'] as int
            : 5,
    difficulty:
        ['foundation', 'standard', 'challenge'].contains(json['difficulty'])
            ? json['difficulty'] as String
            : 'standard',
    focus:
        json['focus'] is String
            ? (json['focus'] as String).substring(
              0,
              (json['focus'] as String).length.clamp(0, 300),
            )
            : '',
  );
}

class StudySpace {
  const StudySpace({
    required this.id,
    required this.name,
    this.documentIds = const [],
    this.createdAt = '',
  });

  final String id;
  final String name;
  final List<String> documentIds;
  final String createdAt;

  StudySpace copyWith({String? name, List<String>? documentIds}) => StudySpace(
    id: id,
    name: name ?? this.name,
    documentIds: documentIds ?? this.documentIds,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'documentIds': documentIds,
    'createdAt': createdAt,
  };

  factory StudySpace.fromJson(Map<String, dynamic> json) => StudySpace(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? 'Study space'}',
    documentIds:
        (json['documentIds'] as List? ?? const []).whereType<String>().toList(),
    createdAt: '${json['createdAt'] ?? ''}',
  );
}

class StudyNote {
  const StudyNote({
    required this.id,
    required this.spaceId,
    required this.title,
    required this.body,
    required this.documentId,
    required this.documentTitle,
    this.sourcePage,
    this.createdAt = '',
  });

  final String id;
  final String spaceId;
  final String title;
  final String body;
  final String documentId;
  final String documentTitle;
  final int? sourcePage;
  final String createdAt;

  StudyNote copyWith({String? title, String? body}) => StudyNote(
    id: id,
    spaceId: spaceId,
    title: title ?? this.title,
    body: body ?? this.body,
    documentId: documentId,
    documentTitle: documentTitle,
    sourcePage: sourcePage,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'spaceId': spaceId,
    'title': title,
    'body': body,
    'documentId': documentId,
    'documentTitle': documentTitle,
    'sourcePage': sourcePage,
    'createdAt': createdAt,
  };

  factory StudyNote.fromJson(Map<String, dynamic> json) => StudyNote(
    id: '${json['id'] ?? ''}',
    spaceId: '${json['spaceId'] ?? ''}',
    title: '${json['title'] ?? 'Study note'}',
    body: '${json['body'] ?? ''}',
    documentId: '${json['documentId'] ?? ''}',
    documentTitle: '${json['documentTitle'] ?? 'Source document'}',
    sourcePage: (json['sourcePage'] as num?)?.toInt(),
    createdAt: '${json['createdAt'] ?? ''}',
  );
}

class StudyQuestion {
  const StudyQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    required this.sourceDocumentId,
    required this.sourceTitle,
    this.sourceExcerpt = '',
    this.sourcePage,
    this.selectedIndex,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String sourceDocumentId;
  final String sourceTitle;
  final String sourceExcerpt;
  final int? sourcePage;
  final int? selectedIndex;

  StudyQuestion copyWith({int? selectedIndex}) => StudyQuestion(
    prompt: prompt,
    options: options,
    correctIndex: correctIndex,
    explanation: explanation,
    sourceDocumentId: sourceDocumentId,
    sourceTitle: sourceTitle,
    sourceExcerpt: sourceExcerpt,
    sourcePage: sourcePage,
    selectedIndex: selectedIndex ?? this.selectedIndex,
  );

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'options': options,
    'correctIndex': correctIndex,
    'explanation': explanation,
    'sourceDocumentId': sourceDocumentId,
    'sourceTitle': sourceTitle,
    'sourceExcerpt': sourceExcerpt,
    'sourcePage': sourcePage,
    'selectedIndex': selectedIndex,
  };

  factory StudyQuestion.fromJson(Map<String, dynamic> json) => StudyQuestion(
    prompt: '${json['prompt'] ?? ''}',
    options: (json['options'] as List? ?? const []).map((e) => '$e').toList(),
    correctIndex:
        json['correctIndex'] is int ? json['correctIndex'] as int : -1,
    explanation: '${json['explanation'] ?? ''}',
    sourceDocumentId: '${json['sourceDocumentId'] ?? ''}',
    sourceTitle: '${json['sourceTitle'] ?? 'Source document'}',
    sourceExcerpt: '${json['sourceExcerpt'] ?? ''}',
    sourcePage: (json['sourcePage'] as num?)?.toInt(),
    selectedIndex:
        json['selectedIndex'] is num &&
                (json['selectedIndex'] as num) >= 0 &&
                (json['selectedIndex'] as num) <
                    (json['options'] as List? ?? []).length
            ? (json['selectedIndex'] as num).toInt()
            : null,
  );
}

class StudyQuiz {
  const StudyQuiz({required this.questions, this.completed = false});
  final List<StudyQuestion> questions;
  final bool completed;

  StudyQuiz copyWith({List<StudyQuestion>? questions, bool? completed}) =>
      StudyQuiz(
        questions: questions ?? this.questions,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
    'questions': questions.map((question) => question.toJson()).toList(),
    'completed': completed,
  };

  factory StudyQuiz.fromJson(Map<String, dynamic> json) => StudyQuiz(
    questions:
        (json['questions'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => StudyQuestion.fromJson(Map<String, dynamic>.from(item)),
            )
            .where(
              (q) =>
                  q.options.length == 4 &&
                  q.correctIndex >= 0 &&
                  q.correctIndex < 4 &&
                  q.prompt.isNotEmpty,
            )
            .toList(),
    completed: json['completed'] == true,
  );
}

/// Revision uses explicit self ratings; no claim that recall proves mastery.
class StudyCard {
  const StudyCard({
    required this.id,
    required this.spaceId,
    required this.front,
    required this.back,
    required this.documentId,
    required this.documentTitle,
    this.sourcePage,
    this.sourceExcerpt = '',
    this.dueAt = '',
    this.intervalDays = 0,
    this.reviews = 0,
  });
  final String id, spaceId, front, back, documentId, documentTitle;
  final String sourceExcerpt, dueAt;
  final int? sourcePage;
  final int intervalDays, reviews;
  bool due(DateTime now) => DateTime.tryParse(dueAt)?.isAfter(now) != true;
  StudyCard reviewed(bool recalled, DateTime now) {
    final interval =
        recalled
            ? (intervalDays == 0 ? 1 : (intervalDays * 2).clamp(1, 30))
            : 0;
    return StudyCard(
      id: id,
      spaceId: spaceId,
      front: front,
      back: back,
      documentId: documentId,
      documentTitle: documentTitle,
      sourcePage: sourcePage,
      sourceExcerpt: sourceExcerpt,
      intervalDays: interval,
      reviews: reviews + 1,
      dueAt:
          now
              .add(
                recalled
                    ? Duration(days: interval)
                    : const Duration(minutes: 10),
              )
              .toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'spaceId': spaceId,
    'front': front,
    'back': back,
    'documentId': documentId,
    'documentTitle': documentTitle,
    'sourcePage': sourcePage,
    'sourceExcerpt': sourceExcerpt,
    'dueAt': dueAt,
    'intervalDays': intervalDays,
    'reviews': reviews,
  };
  factory StudyCard.fromJson(Map<String, dynamic> j) => StudyCard(
    id: '${j['id'] ?? ''}',
    spaceId: '${j['spaceId'] ?? ''}',
    front: '${j['front'] ?? ''}',
    back: '${j['back'] ?? ''}',
    documentId: '${j['documentId'] ?? ''}',
    documentTitle: '${j['documentTitle'] ?? ''}',
    sourcePage: (j['sourcePage'] as num?)?.toInt(),
    sourceExcerpt: '${j['sourceExcerpt'] ?? ''}',
    dueAt: '${j['dueAt'] ?? ''}',
    intervalDays: (j['intervalDays'] as num?)?.toInt() ?? 0,
    reviews: (j['reviews'] as num?)?.toInt() ?? 0,
  );
}

class StudyProgress {
  const StudyProgress(this.answered, this.correct, this.rounds);
  final int answered, correct, rounds;
  double get accuracy => answered == 0 ? 0 : correct / answered;
}
