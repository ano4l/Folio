import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document.dart';
import 'api_service.dart';
import 'workspace_store.dart';

class AppState extends ChangeNotifier {
  AppState({ApiService? api, WorkspaceStore? store})
    : api = api ?? ApiService(),
      store = store ?? WorkspaceStore();

  final ApiService api;
  final WorkspaceStore store;
  int _session = 0;
  bool _disposed = false;
  final Map<String, Completer<void>> _requests = {};
  final Map<String, String> _drafts = {};
  final Map<String, String> _chatErrors = {};
  Timer? _saveTimer;
  Future<void> _writes = Future.value();
  String cacheError = '';
  int navigationIndex = 0;
  void navigate(int index) {
    navigationIndex = index;
    notifyListeners();
  }

  void openDocument(Document doc) {
    navigationIndex = 1;
    selectDoc(doc);
  }

  String authStep = 'checking'; // checking | credentials | mfa | authenticated
  AuthUser? user;
  String challengeId = '';
  String authMode = 'login';
  String authError = '';
  bool authLoading = false;
  int resendSeconds = 0;

  List<Document> documents = [];
  List<Document> deletedDocs = [];
  Document? selectedDoc;
  List<Deadline> deadlines = [];
  List<AuditEntry> auditLogs = [];
  bool documentsLoading = false;
  String documentsError = '';

  final Map<String, List<ChatMessage>> _chatByDocument = {
    'all': const [
      ChatMessage(
        role: 'assistant',
        text:
            'Hi — ask me to explain, compare, summarise, draft, or reason through anything in your documents. I’ll show the sources I used and say when the evidence is uncertain.',
      ),
    ],
  };
  String? activeChatDocumentId;
  bool get aiTyping => isChatBusy(activeChatDocumentId);
  bool isChatBusy(String? id) => _requests.containsKey(id ?? 'all');
  String chatError(String? id) => _chatErrors[id ?? 'all'] ?? '';
  String draftFor(String? id) => _drafts[id ?? 'all'] ?? '';
  List<ChatMessage> messagesFor(String? id) =>
      _chatByDocument[id ?? 'all'] ?? const [];
  void setDraft(String? id, String text) {
    _drafts[id ?? 'all'] = text;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 350),
      () => persistWorkspace(),
    );
  }

  Future<void> persistWorkspace() {
    final owner = user?.id;
    if (owner == null || _disposed) return Future.value();
    // Snapshot before queueing so later account changes cannot alter a write.
    final snapshot =
        jsonDecode(
              jsonEncode({
                'chats': _chatByDocument.map(
                  (k, v) => MapEntry(k, v.map((m) => m.toJson()).toList()),
                ),
                'drafts': _drafts,
                'documents': documents.map((d) => d.toJson()).toList(),
                'deleted': deletedDocs.map((d) => d.toJson()).toList(),
                'deadlines': deadlines.map((d) => d.toJson()).toList(),
              }),
            )
            as Map<String, dynamic>;
    final generation = _session;
    _writes = _writes
        .then((_) => store.write(owner, snapshot))
        .then((_) {
          if (_session == generation && !_disposed && cacheError.isNotEmpty) {
            cacheError = '';
            notifyListeners();
          }
        })
        .catchError((Object error) {
          if (_session == generation && !_disposed) {
            cacheError =
                'Changes could not be saved on this device. Keep the app open and try again.';
            notifyListeners();
          }
        });
    return _writes;
  }

  Future<void> restoreWorkspace() async {
    final owner = user?.id;
    if (owner == null) return;
    final generation = _session;
    try {
      await _writes;
      final data = await store.read(owner);
      if (generation != _session || user?.id != owner) return;
      for (final entry in (data['chats'] as Map? ?? {}).entries) {
        _chatByDocument[entry.key as String] =
            (entry.value as List)
                .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
                .toList();
      }
      _drafts.addAll(Map<String, String>.from(data['drafts'] ?? {}));
      documents =
          (data['documents'] as List? ?? [])
              .map((d) => Document.fromJson(Map<String, dynamic>.from(d)))
              .toList();
      deletedDocs =
          (data['deleted'] as List? ?? [])
              .map((d) => Document.fromJson(Map<String, dynamic>.from(d)))
              .toList();
      deadlines =
          (data['deadlines'] as List? ?? [])
              .map((d) => Deadline.fromJson(Map<String, dynamic>.from(d)))
              .toList();
    } catch (_) {
      if (generation == _session) {
        cacheError = 'Saved data could not be opened on this device.';
      }
    }
    if (generation == _session) notifyListeners();
  }

  void _resetAccount() {
    _session++;
    _saveTimer?.cancel();
    for (final request in _requests.values) {
      if (!request.isCompleted) request.complete();
    }
    _requests.clear();
    _chatErrors.clear();
    _drafts.clear();
    _chatByDocument.clear();
    documents = [];
    deletedDocs = [];
    deadlines = [];
    auditLogs = [];
    selectedDoc = null;
    activeChatDocumentId = null;
    navigationIndex = 0;
    documentsLoading = false;
    documentsError = '';
    cacheError = '';
    appLocked = false;
    challengeId = '';
    user = null;
  }

  bool biometricEnabled = false;
  bool biometricAvailable = false;
  bool appLocked = false;

  int get pendingCount => deadlines.where((item) => !item.completed).length;
  List<ChatMessage> get chatMessages => messagesFor(activeChatDocumentId);
  String get firstName =>
      (user?.displayName.trim().split(RegExp(r'\s+')).firstOrNull ?? 'there');

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      biometricEnabled = preferences.getBool('biometric_enabled') ?? false;
      await api.initialize();
      user = await api.currentUser();
      authStep = 'authenticated';
      appLocked = biometricEnabled;
      await restoreWorkspace();
      await refreshDocuments();
    } on ApiException catch (error) {
      if (error.statusCode == 401) await api.clearSession();
      _resetAccount();
      authStep = 'credentials';
    } catch (_) {
      _resetAccount();
      authStep = 'credentials';
      authError = 'Could not restore your session. Please sign in again.';
    } finally {
      notifyListeners();
    }
  }

  Future<bool> submitCredentials({
    required String mode,
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (authLoading) return false;
    final generation = _session;
    authLoading = true;
    authError = '';
    authMode = mode;
    notifyListeners();
    try {
      final response = await api.beginAuth(
        mode: mode,
        email: email,
        password: password,
        displayName: displayName,
      );
      if (_disposed || generation != _session) return false;
      challengeId = '${response['challengeId'] ?? ''}';
      resendSeconds = (response['resendAfterSeconds'] as num?)?.toInt() ?? 60;
      authStep = 'mfa';
      return true;
    } catch (error) {
      if (generation == _session) {
        authError =
            error is ApiException
                ? error.message
                : 'Sign-in could not finish. Please try again.';
      }
      return false;
    } finally {
      if (!_disposed && generation == _session) {
        authLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> verifyMfa(String code) async {
    if (authLoading) return false;
    final generation = _session;
    authLoading = true;
    authError = '';
    notifyListeners();
    try {
      final verified = await api.verifyOtp(challengeId, code);
      if (_disposed || generation != _session) return false;
      user = verified;
      authStep = 'authenticated';
      appLocked = false;
      await restoreWorkspace();
      await refreshDocuments();
      if (_disposed || generation != _session) return false;
      _addAuditLog(
        'Secure Session Started',
        'Email MFA verified and an encrypted Folio session was created.',
        'Security',
      );
      return true;
    } catch (error) {
      if (generation == _session) {
        authError =
            error is ApiException
                ? error.message
                : 'Verification could not finish. Please try again.';
      }
      return false;
    } finally {
      if (!_disposed && generation == _session) {
        authLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> resendMfa() async {
    if (authLoading) return false;
    final generation = _session;
    authLoading = true;
    authError = '';
    notifyListeners();
    try {
      final response = await api.resendOtp(challengeId);
      if (_disposed || generation != _session) return false;
      challengeId = '${response['challengeId'] ?? challengeId}';
      resendSeconds = (response['resendAfterSeconds'] as num?)?.toInt() ?? 60;
      return true;
    } catch (error) {
      if (generation == _session) {
        authError =
            error is ApiException
                ? error.message
                : 'The code could not be resent. Please try again.';
      }
      return false;
    } finally {
      if (!_disposed && generation == _session) {
        authLoading = false;
        notifyListeners();
      }
    }
  }

  void backToCredentials() {
    _session++;
    authLoading = false;
    authStep = 'credentials';
    authError = '';
    notifyListeners();
  }

  Future<void> logout() async {
    unawaited(persistWorkspace());
    _resetAccount();
    authLoading = true;
    authStep = 'credentials';
    notifyListeners();
    try {
      await api.logout();
    } catch (_) {
      /* local session is cleared in API finally */
    } finally {
      authLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refreshDocuments() async {
    final generation = _session;
    documentsLoading = true;
    documentsError = '';
    notifyListeners();
    try {
      final loaded = await api.fetchDocuments();
      if (generation != _session) return;
      documents = loaded;
      if (selectedDoc != null) {
        selectedDoc =
            documents.where((d) => d.id == selectedDoc!.id).firstOrNull;
      }
      unawaited(persistWorkspace());
    } on ApiException catch (error) {
      if (generation != _session) return;
      documentsError = error.message;
      if (error.statusCode == 401) {
        _resetAccount();
        authStep = 'credentials';
        await api.clearSession();
        if (!_disposed) notifyListeners();
      }
    } catch (_) {
      if (generation == _session) {
        documentsError =
            'Could not refresh your vault. Your saved documents are still available.';
      }
    } finally {
      if (generation == _session) {
        documentsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<String> uploadDocument(
    String filePath,
    String title, {
    String category = 'Document',
    ValueChanged<String>? onStage,
  }) async {
    final generation = _session;
    final result = await api.uploadDocument(
      filePath: filePath,
      title: title,
      category: category,
      onStage: onStage,
    );
    if (generation != _session) return result;
    await refreshDocuments();
    if (generation != _session) return result;
    _addAuditLog(
      'Upload Completed',
      "Uploaded '$title' to the private document vault.",
      'Document',
    );
    return result;
  }

  void selectDoc(Document? doc) {
    selectedDoc = doc;
    if (doc != null) {
      _addAuditLog(
        'Document Viewed',
        '${doc.title} (activity on this device)',
        'Access',
      );
    }
    notifyListeners();
  }

  Future<void> softDeleteDoc(Document doc) async {
    final generation = _session;
    await api.deleteDocument(doc.id);
    if (generation != _session) return;
    stopChat(doc.id);
    documents.removeWhere((item) => item.id == doc.id);
    deletedDocs.insert(0, doc);
    if (selectedDoc?.id == doc.id) selectedDoc = null;
    _addAuditLog(
      'Document Deleted',
      "'${doc.title}' moved to the recycle bin",
      'Document',
    );
    notifyListeners();
    unawaited(persistWorkspace());
  }

  Future<void> restoreDoc(Document doc) async {
    final generation = _session;
    await api.restoreDocument(doc.id);
    if (generation != _session) return;
    deletedDocs.removeWhere((item) => item.id == doc.id);
    await refreshDocuments();
    if (generation != _session) return;
    _addAuditLog(
      'Document Restored',
      "'${doc.title}' recovered from the recycle bin",
      'Document',
    );
  }

  void setChatDocument(String? documentId) {
    activeChatDocumentId = documentId;
    notifyListeners();
  }

  Future<void> sendChat(String question, {String? documentId}) async {
    final clean = question.trim();
    if (clean.isEmpty ||
        clean.length > 2000 ||
        isChatBusy(documentId) ||
        user == null) {
      return;
    }
    if (documentId != null &&
        !documents.any((d) => d.id == documentId && d.status == 'Ready')) {
      return;
    }
    final generation = _session;
    final key = documentId ?? 'all';
    final abort = Completer<void>();
    _requests[key] = abort;
    _chatErrors.remove(key);
    final history =
        messagesFor(documentId)
            .where(
              (m) => !m.incomplete && ['user', 'assistant'].contains(m.role),
            )
            .toList();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _chatByDocument[key] = [
      ...messagesFor(documentId),
      ChatMessage(id: '$id-q', role: 'user', text: clean),
      ChatMessage(id: '$id-a', role: 'streaming', text: ''),
    ];
    _drafts[key] = '';
    unawaited(persistWorkspace());
    notifyListeners();
    var answer = '';
    List<Map<String, String>> sources = [];
    var completed = false;
    final updates = Stopwatch()..start();
    bool current() =>
        !_disposed &&
        generation == _session &&
        identical(_requests[key], abort);
    void replace(ChatMessage message) {
      final list = _chatByDocument[key];
      if (list == null || list.isEmpty) return;
      list[list.length - 1] = message;
    }

    try {
      await for (final event in api.ask(
        question: clean,
        history: history,
        documentId: documentId,
        abortTrigger: abort.future,
      )) {
        if (!current()) return;
        final type = '${event['type'] ?? ''}';
        if (type == 'delta') answer += '${event['text'] ?? ''}';
        if (type == 'replace') answer = '${event['text'] ?? ''}';
        if (type == 'done') {
          completed = true;
          sources =
              (event['citations'] as List? ?? const []).whereType<Map>().map((
                item,
              ) {
                final map = Map<String, dynamic>.from(item);
                return {
                  'documentId': '${map['documentId'] ?? ''}',
                  'number': '${map['number'] ?? ''}',
                  'doc': '${map['title'] ?? 'Document'}',
                  'page': '${map['page'] ?? ''}',
                  'excerpt': '${map['excerpt'] ?? ''}',
                  'detail':
                      map['page'] == null
                          ? 'Source document'
                          : 'Page ${map['page']}',
                };
              }).toList();
        }
        replace(
          ChatMessage(
            id: '$id-a',
            role: 'streaming',
            text: answer,
            sources: sources,
          ),
        );
        if (updates.elapsedMilliseconds >= 70 || type != 'delta') {
          notifyListeners();
          updates.reset();
        }
      }
      if (!current()) return;
      replace(
        ChatMessage(
          id: '$id-a',
          role: 'assistant',
          text: answer,
          sources: sources,
          incomplete: !completed,
        ),
      );
      if (!completed) {
        _chatErrors[key] =
            'The response was interrupted. You can retry your question.';
      }
      _addAuditLog(
        'AI Grounded Query',
        'Asked Folio about ${documentId == null ? 'all documents' : 'one document'}.',
        'AI Queries',
      );
    } catch (error) {
      if (!current()) return;
      replace(
        ChatMessage(
          id: '$id-a',
          role: 'assistant',
          text: answer,
          incomplete: true,
        ),
      );
      _chatErrors[key] =
          error is ApiException
              ? error.message
              : 'Connection interrupted. Your question and any partial answer are saved.';
      if (error is ApiException && error.statusCode == 401) {
        unawaited(persistWorkspace());
        _resetAccount();
        authStep = 'credentials';
        await api.clearSession();
        if (!_disposed) notifyListeners();
      }
    } finally {
      if (current()) {
        _requests.remove(key);
        unawaited(persistWorkspace());
        notifyListeners();
      }
    }
  }

  void stopChat(String? documentId) {
    final key = documentId ?? 'all';
    final request = _requests.remove(key);
    if (request == null) return;
    request.complete();
    final messages = _chatByDocument[key];
    if (messages != null &&
        messages.isNotEmpty &&
        messages.last.role == 'streaming') {
      messages[messages.length - 1] = messages.last.copyWith(
        role: 'assistant',
        incomplete: true,
      );
    }
    _chatErrors[key] =
        'Response stopped. You can retry or ask another question.';
    unawaited(persistWorkspace());
    notifyListeners();
  }

  Future<void> retryChat(String? documentId) async {
    if (isChatBusy(documentId)) return;
    final key = documentId ?? 'all';
    final messages = _chatByDocument[key];
    if (messages == null) return;
    final index = messages.lastIndexWhere((m) => m.role == 'user');
    if (index < 0) return;
    final question = messages[index].text;
    messages.removeRange(index, messages.length);
    await sendChat(question, documentId: documentId);
  }

  void clearChat(String? documentId) {
    stopChat(documentId);
    _chatByDocument.remove(documentId ?? 'all');
    _chatErrors.remove(documentId ?? 'all');
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void toggleSaved(String? documentId, String messageId) {
    final messages = _chatByDocument[documentId ?? 'all'];
    if (messages == null) return;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    messages[index] = messages[index].copyWith(saved: !messages[index].saved);
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void addDeadline({
    required Document doc,
    required String action,
    required DateTime due,
  }) {
    deadlines.add(
      Deadline(
        id: DateTime.now().microsecondsSinceEpoch,
        action: action.trim(),
        doc: doc.title,
        documentId: doc.id,
        due: DateTime(due.year, due.month, due.day).toIso8601String(),
        days: 0,
        severity: 'medium',
      ),
    );
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void resolveDeadline(int id) {
    final item = deadlines.where((deadline) => deadline.id == id).firstOrNull;
    if (item != null) item.completed = !item.completed;
    unawaited(persistWorkspace());
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    biometricEnabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('biometric_enabled', value);
    notifyListeners();
  }

  void setBiometricAvailable(bool value) {
    biometricAvailable = value;
    notifyListeners();
  }

  void lock() {
    if (authStep == 'authenticated' && biometricEnabled) {
      appLocked = true;
      notifyListeners();
    }
  }

  void unlock() {
    appLocked = false;
    notifyListeners();
  }

  void _addAuditLog(String action, String detail, String category) {
    final now = DateTime.now();
    auditLogs.insert(
      0,
      AuditEntry(
        id: now.millisecondsSinceEpoch,
        time: now.toLocal().toString().substring(0, 16),
        actor: user?.displayName ?? 'Student',
        action: action,
        detail: detail,
        category: category,
      ),
    );
  }

  @override
  void dispose() {
    _session++;
    _disposed = true;
    _saveTimer?.cancel();
    for (final request in _requests.values) {
      if (!request.isCompleted) request.complete();
    }
    _requests.clear();
    api.dispose();
    super.dispose();
  }
}
