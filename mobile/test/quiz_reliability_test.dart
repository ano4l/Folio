import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:folio_mobile/models/document.dart';
import 'package:folio_mobile/models/study.dart';
import 'package:folio_mobile/services/api_service.dart';
import 'package:folio_mobile/services/app_state.dart';
import 'package:folio_mobile/services/workspace_store.dart';

class MemoryStore extends WorkspaceStore {
  @override
  Future<void> write(String id, Map<String, dynamic> value) async {}
}

class RetryApi extends ApiService {
  final requests = <QuizRequest>[];
  @override
  Future<StudyQuiz> generateQuiz(
    String documentId, {
    Future<void>? abortTrigger,
    int count = 5,
    String difficulty = 'standard',
    String focus = '',
  }) async {
    requests.add(
      QuizRequest(count: count, difficulty: difficulty, focus: focus),
    );
    throw const ApiException('Temporary provider failure', 503);
  }
}

void main() {
  test(
    'failed quizzes retain length difficulty and topic on retry and cache restore',
    () async {
      final api = RetryApi();
      final state =
          AppState(api: api, store: MemoryStore())
            ..user = const AuthUser(
              id: 'owner',
              email: 'owner@example.invalid',
              displayName: 'Owner',
            )
            ..documents = [
              const Document(
                id: 'source',
                title: 'Database notes',
                type: 'Lecture Notes',
                date: '',
                pages: 1,
                status: 'Ready',
                confidence: 100,
                summary: '',
                entities: [],
                rawText: 'Source text',
              ),
            ];
      await state.generateQuiz(
        'source',
        count: 8,
        difficulty: 'challenge',
        focus: 'transactions',
      );
      final userMessage = state
          .messagesFor('source')
          .firstWhere((item) => item.role == 'user');
      final restored = ChatMessage.fromJson(
        jsonDecode(jsonEncode(userMessage.toJson())),
      );
      expect(restored.quizRequest!.count, 8);
      expect(restored.quizRequest!.difficulty, 'challenge');
      expect(restored.quizRequest!.focus, 'transactions');
      await state.retryChat('source');
      expect(api.requests.length, 2);
      expect(api.requests.last.toJson(), api.requests.first.toJson());
      state.dispose();
    },
  );

  test(
    'quiz responses cannot turn missing answer keys or wrong source IDs into valid questions',
    () async {
      final valid = <String, dynamic>{
        'prompt': 'What does a primary key identify?',
        'options': ['Each row', 'A server', 'A timeout', 'All tables'],
        'correctIndex': 0,
        'explanation': 'It uniquely identifies each row.',
        'sourceDocumentId': 'source',
        'sourceTitle': 'Notes',
        'sourceExcerpt': 'A primary key uniquely identifies each row',
        'sourcePage': 1,
      };
      for (final changed in [
        <String, dynamic>{'correctIndex': null},
        {'correctIndex': 0.5},
        {'sourceDocumentId': 'other-owner'},
        {'sourceExcerpt': ''},
        {'sourcePage': 1.5},
        {
          'options': ['a', 2, 'c', 'd'],
        },
      ]) {
        final api = ApiService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'questions': [
                  {...valid, ...changed},
                ],
              }),
              200,
            ),
          ),
        );
        await expectLater(
          api.generateQuiz('source'),
          throwsA(isA<ApiException>()),
        );
      }
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'questions': [valid],
            }),
            200,
          ),
        ),
      );
      expect(
        (await api.generateQuiz('source')).questions.single.correctIndex,
        0,
      );
    },
  );
}
