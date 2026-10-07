import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:folio_mobile/models/document.dart';
import 'package:folio_mobile/services/api_service.dart';
import 'package:folio_mobile/services/app_state.dart';
import 'package:folio_mobile/services/workspace_store.dart';

const doc = Document(
  id: 'doc-a',
  title: 'Bursary',
  type: 'Agreement',
  date: '',
  pages: 2,
  status: 'Ready',
  confidence: 0,
  summary: 'Summary',
  entities: [],
  rawText: 'Source',
);
const owner = AuthUser(
  id: 'alice',
  email: 'alice@example.test',
  displayName: 'Alice',
);

class MemoryStore extends WorkspaceStore {
  final data = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> read(String id) async => data[id] ?? {};
  @override
  Future<void> write(String id, Map<String, dynamic> value) async {
    data[id] = value;
  }
}

class FakeApi extends ApiService {
  final responses = <StreamController<Map<String, dynamic>>>[];
  Completer<List<Document>>? fetch;
  Completer<AuthUser>? verification;
  @override
  Future<void> logout() async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<List<Document>> fetchDocuments() =>
      fetch?.future ?? Future.value([doc]);
  @override
  Future<AuthUser> verifyOtp(String challenge, String code) =>
      verification!.future;
  @override
  Stream<Map<String, dynamic>> ask({
    required String question,
    required List<ChatMessage> history,
    String? documentId,
    Future<void>? abortTrigger,
  }) {
    final controller = StreamController<Map<String, dynamic>>();
    responses.add(controller);
    return controller.stream;
  }
}

AppState stateFor(FakeApi api, MemoryStore store) =>
    AppState(api: api, store: store)
      ..user = owner
      ..authStep = 'authenticated'
      ..documents = [doc];

void main() {
  test(
    'invalid successful API payload does not erase cached documents',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response('<html>Temporary outage</html>', 200),
        ),
      );
      final state =
          AppState(api: api, store: MemoryStore())
            ..user = owner
            ..documents = [doc];
      await state.refreshDocuments();
      expect(state.documents.single.id, doc.id);
      expect(state.documentsError, isNotEmpty);
      state.dispose();
    },
  );
  test('document history and drafts restore only for their owner', () async {
    final store = MemoryStore();
    final api = FakeApi();
    final state = stateFor(api, store);
    state.setDraft(doc.id, 'My private draft');
    final send = state.sendChat('Explain it', documentId: doc.id);
    api.responses.single.add({'type': 'delta', 'text': 'A grounded answer'});
    api.responses.single.add({
      'type': 'done',
      'citations': [
        {'documentId': doc.id, 'title': doc.title, 'page': 2, 'number': 1},
      ],
    });
    await api.responses.single.close();
    await send;
    state.setDraft(doc.id, 'Next question');
    await state.persistWorkspace();
    await state.logout();
    expect(state.messagesFor(doc.id), isEmpty);
    expect(state.deadlines, isEmpty);
    expect(state.deletedDocs, isEmpty);
    state.user = const AuthUser(id: 'bob', email: '', displayName: 'Bob');
    await state.restoreWorkspace();
    expect(state.messagesFor(doc.id), isEmpty);
    expect(state.draftFor(doc.id), isEmpty);
    state.user = owner;
    await state.restoreWorkspace();
    expect(state.messagesFor(doc.id).last.sources.single['page'], '2');
    expect(state.draftFor(doc.id), 'Next question');
    state.dispose();
  });

  test('stopped stream cannot overwrite a new response', () async {
    final api = FakeApi();
    final state = stateFor(api, MemoryStore());
    final first = state.sendChat('First', documentId: doc.id);
    state.stopChat(doc.id);
    final second = state.sendChat('Second', documentId: doc.id);
    api.responses[0].add({'type': 'delta', 'text': 'STALE'});
    await api.responses[0].close();
    await first;
    api.responses[1].add({'type': 'delta', 'text': 'CURRENT'});
    api.responses[1].add({'type': 'done'});
    await api.responses[1].close();
    await second;
    expect(state.messagesFor(doc.id).last.text, 'CURRENT');
    expect(
      state.messagesFor(doc.id).any((m) => m.text.contains('STALE')),
      false,
    );
    state.dispose();
  });

  test(
    'late document fetch and MFA cannot repopulate a signed-out account',
    () async {
      final api =
          FakeApi()
            ..fetch = Completer<List<Document>>()
            ..verification = Completer<AuthUser>();
      final state = stateFor(api, MemoryStore());
      final refresh = state.refreshDocuments();
      final verify = state.verifyMfa('123456');
      await state.logout();
      api.fetch!.complete([doc]);
      api.verification!.complete(owner);
      await refresh;
      expect(await verify, false);
      expect(state.user, isNull);
      expect(state.documents, isEmpty);
      expect(state.authStep, 'credentials');
      state.dispose();
    },
  );

  test('partial stream is saved as interrupted and can be retried', () async {
    final api = FakeApi();
    final state = stateFor(api, MemoryStore());
    final send = state.sendChat('Question', documentId: doc.id);
    api.responses.single.add({'type': 'delta', 'text': 'Partial'});
    await api.responses.single.close();
    await send;
    expect(state.messagesFor(doc.id).last.incomplete, true);
    expect(state.chatError(doc.id), isNotEmpty);
    final retry = state.retryChat(doc.id);
    api.responses.last.add({'type': 'delta', 'text': 'Complete'});
    api.responses.last.add({'type': 'done'});
    await api.responses.last.close();
    await retry;
    expect(state.messagesFor(doc.id).length, 2);
    expect(state.messagesFor(doc.id).last.incomplete, false);
    state.dispose();
  });

  test('API sends latest ten messages, not the oldest ten', () async {
    late Map<String, dynamic> payload;
    final api = ApiService(
      client: MockClient((request) async {
        payload = jsonDecode(request.body);
        return http.Response('{"type":"done"}\n', 200);
      }),
    );
    await api
        .ask(
          question: 'Now?',
          history: List.generate(
            18,
            (i) =>
                ChatMessage(role: i.isEven ? 'user' : 'assistant', text: '$i'),
          ),
        )
        .drain<void>();
    expect((payload['history'] as List).first['text'], '8');
    expect((payload['history'] as List).last['text'], '17');
    api.dispose();
  });

  test('tasks retain source, date and completion after restart', () async {
    final store = MemoryStore();
    final state = stateFor(FakeApi(), store);
    state.addDeadline(
      doc: doc,
      action: 'Submit renewal',
      due: DateTime.now().add(const Duration(days: 3)),
    );
    state.resolveDeadline(state.deadlines.single.id);
    await state.persistWorkspace();
    final restored = stateFor(FakeApi(), store);
    await restored.restoreWorkspace();
    expect(restored.deadlines.single.documentId, doc.id);
    expect(restored.deadlines.single.completed, true);
    expect(restored.deadlines.single.days, 3);
    state.dispose();
    restored.dispose();
  });
}
