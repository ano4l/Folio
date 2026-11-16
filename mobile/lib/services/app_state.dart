import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document.dart';
import '../models/document_upload.dart';
import '../models/study.dart';
import 'api_service.dart';
import 'workspace_store.dart';
import 'document_deadlines.dart';

class AppState extends ChangeNotifier {
  AppState({
    ApiService? api,
    WorkspaceStore? store,
    Future<List<DocumentDeadlineCandidate>> Function(List<Document>)?
    deadlineExtractor,
  }) : api = api ?? ApiService(),
       store = store ?? WorkspaceStore(),
       _deadlineExtractor =
           deadlineExtractor ??
           ((documents) => compute(extractDocumentDeadlines, documents));

  final ApiService api;
  final WorkspaceStore store;
  final Future<List<DocumentDeadlineCandidate>> Function(List<Document>)
  _deadlineExtractor;
  int _session = 0;
  bool _disposed = false;
  final Map<String, Completer<void>> _requests = {};
  final Map<String, String> _drafts = {};
  final Map<String, String> _chatErrors = {};
  Timer? _saveTimer;
  Timer? _workspaceSaveTimer;
  Completer<void>? _pendingWorkspaceSave;
  Future<void> _writes = Future.value();
  String cacheError = '';
  int navigationIndex = 0;
  void navigate(int index) {
    navigationIndex = index;
    notifyListeners();
  }

  void openDocument(Document doc) => selectDoc(doc);

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
  List<DocumentDeadlineCandidate> deadlineDateReviews = [];
  final Set<String> _dismissedDocumentDeadlines = {};
  int _deadlineScan = 0;
  List<AuditEntry> auditLogs = [];
  List<StudySpace> studySpaces = [];
  List<StudyNote> studyNotes = [];
  List<StudyCard> studyCards = [];
  Set<String> favoriteDocumentIds = {};
  bool documentsLoading = false;
  String documentsError = '';
  List<DocumentUpload> documentUploads = const [];
  final Set<String> _automaticProcessingAttempted = {};
  int _nextUploadId = 0;
  int _documentsRequest = 0;

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
    if (user == null || _disposed) return Future.value();
    // Coalesce bursts (activity + document/task updates) into one snapshot.
    // Do not restart the timer: continuous input must still reach storage.
    final pending = _pendingWorkspaceSave ??= Completer<void>();
    _workspaceSaveTimer ??= Timer(
      const Duration(milliseconds: 250),
      flushWorkspace,
    );
    return pending.future;
  }

  void flushWorkspace() {
    final draftPending = _saveTimer?.isActive == true;
    _saveTimer?.cancel();
    _saveTimer = null;
    _workspaceSaveTimer?.cancel();
    _workspaceSaveTimer = null;
    final pending =
        _pendingWorkspaceSave ?? (draftPending ? Completer<void>() : null);
    _pendingWorkspaceSave = null;
    if (pending == null) return;
    unawaited(
      _saveWorkspaceNow().whenComplete(() {
        if (!pending.isCompleted) pending.complete();
      }),
    );
  }

  Future<void> _saveWorkspaceNow() {
    final owner = user?.id;
    if (owner == null || _disposed) return Future.value();
    // Snapshot before queueing so later account changes cannot alter a write.
    final snapshot = snapshotWorkspace({
      'chats': _chatByDocument.map(
        (k, v) => MapEntry(k, v.map((m) => m.toJson()).toList()),
      ),
      'drafts': _drafts,
      'favoriteDocumentIds': favoriteDocumentIds.toList(),
      'documents': documents.map((d) => d.toJson()).toList(),
      'deleted': deletedDocs.map((d) => d.toJson()).toList(),
      'deadlines': deadlines.map((d) => d.toJson()).toList(),
      'dismissedDocumentDeadlines': _dismissedDocumentDeadlines.toList(),
      'activity': auditLogs.take(300).map((log) => log.toJson()).toList(),
      'studySpaces': studySpaces.map((space) => space.toJson()).toList(),
      'studyNotes': studyNotes.map((note) => note.toJson()).toList(),
      'studyCards': studyCards.map((card) => card.toJson()).toList(),
    });
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
      auditLogs =
          (data['activity'] as List? ?? [])
              .whereType<Map>()
              .map((j) => AuditEntry.fromJson(Map<String, dynamic>.from(j)))
              .take(300)
              .toList();
      _drafts.addAll(Map<String, String>.from(data['drafts'] ?? {}));
      favoriteDocumentIds =
          (data['favoriteDocumentIds'] as List? ?? [])
              .whereType<String>()
              .toSet();
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
      _dismissedDocumentDeadlines.addAll(
        (data['dismissedDocumentDeadlines'] as List? ?? []).whereType<String>(),
      );
      studySpaces =
          (data['studySpaces'] as List? ?? const [])
              .map(
                (item) => StudySpace.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
      studyCards =
          (data['studyCards'] as List? ?? [])
              .whereType<Map>()
              .map((j) => StudyCard.fromJson(Map<String, dynamic>.from(j)))
              .toList();
      studyNotes =
          (data['studyNotes'] as List? ?? const [])
              .map(
                (item) => StudyNote.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
      await _syncDocumentDeadlines();
    } catch (_) {
      if (generation == _session) {
        cacheError = 'Saved data could not be opened on this device.';
      }
    }
    if (generation == _session) notifyListeners();
  }

  void _resetAccount() {
    flushWorkspace();
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
    documentUploads = const [];
    _automaticProcessingAttempted.clear();
    deletedDocs = [];
    deadlines = [];
    deadlineDateReviews = [];
    _dismissedDocumentDeadlines.clear();
    _deadlineScan++;
    studySpaces = [];
    studyNotes = [];
    studyCards = [];
    favoriteDocumentIds = {};
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
  int launchCount = 0;
  bool biometricOfferShown = false;

  /// Offer biometric unlock once, and never on the very first launch, so the
  /// first screen after sign-in is the workspace rather than a dialog.
  bool get shouldOfferBiometrics =>
      launchCount >= 2 && !biometricEnabled && !biometricOfferShown;

  Future<void> markBiometricOfferShown() async {
    biometricOfferShown = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('biometric_offer_shown', true);
  }

  int get pendingCount => deadlines.where((item) => !item.completed).length;
  List<ChatMessage> get chatMessages => messagesFor(activeChatDocumentId);
  String get firstName =>
      (user?.displayName.trim().split(RegExp(r'\s+')).firstOrNull ?? 'there');

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      biometricEnabled = preferences.getBool('biometric_enabled') ?? false;
      biometricOfferShown =
          preferences.getBool('biometric_offer_shown') ?? false;
      launchCount = (preferences.getInt('launch_count') ?? 0) + 1;
      await preferences.setInt('launch_count', launchCount);
      await api.initialize();
      user = await api.currentUser();
      authStep = 'authenticated';
      appLocked = biometricEnabled;
      await restoreWorkspace();
      await refreshDocuments();
      _resumePendingDocumentProcessing();
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
      _resumePendingDocumentProcessing();
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
    final request = ++_documentsRequest;
    bool current() =>
        !_disposed && generation == _session && request == _documentsRequest;
    documentsLoading = true;
    documentsError = '';
    notifyListeners();
    try {
      final loaded = await api.fetchDocuments();
      if (!current()) return;
      documents = loaded;
      await _syncDocumentDeadlines();
      if (!current()) return;
      if (selectedDoc != null) {
        selectedDoc =
            documents.where((d) => d.id == selectedDoc!.id).firstOrNull;
      }
      unawaited(persistWorkspace());
    } on ApiException catch (error) {
      if (!current()) return;
      documentsError = error.message;
      if (error.statusCode == 401) {
        _resetAccount();
        authStep = 'credentials';
        await api.clearSession();
        if (!_disposed) notifyListeners();
      }
    } catch (_) {
      if (current()) {
        documentsError =
            'Could not refresh your vault. Your saved documents are still available.';
      }
    } finally {
      if (current()) {
        documentsLoading = false;
        notifyListeners();
      }
    }
  }

  void startDocumentUpload(
    String filePath,
    String title, {
    String category = 'Document',
    String? studySpaceId,
  }) {
    unawaited(
      uploadDocument(
        filePath,
        title,
        category: category,
        studySpaceId: studySpaceId,
      ).catchError((Object _) => 'FAILED'),
    );
  }

  void dismissDocumentUpload(int id) {
    documentUploads =
        documentUploads
            .where((upload) => upload.id != id || upload.isRunning)
            .toList();
    notifyListeners();
  }

  void retryDocumentUpload(int id) {
    final upload = documentUploads.where((u) => u.id == id).firstOrNull;
    if (upload == null || upload.isRunning) return;
    dismissDocumentUpload(id);
    if (upload.documentId != null) {
      startDocumentProcessing(upload.documentId!, upload.title);
      return;
    }
    startDocumentUpload(
      upload.filePath,
      upload.title,
      category: upload.category,
      studySpaceId: upload.studySpaceId,
    );
  }

  Future<String> uploadDocument(
    String filePath,
    String title, {
    String category = 'Document',
    ValueChanged<String>? onStage,
    String? studySpaceId,
  }) async {
    final generation = _session;
    final owner = user?.id;
    if (_disposed || owner == null) {
      throw const ApiException('Sign in before uploading a document.', 401);
    }
    final upload = DocumentUpload(
      id: ++_nextUploadId,
      filePath: filePath,
      title: title.trim(),
      category: category,
      studySpaceId: studySpaceId,
    );
    documentUploads = [...documentUploads, upload];
    notifyListeners();
    void update(String stage, UploadStatus status, {String? documentId}) {
      if (_disposed || generation != _session || owner != user?.id) return;
      documentUploads =
          documentUploads
              .map(
                (u) =>
                    u.id == upload.id
                        ? u.update(stage, status, documentId: documentId)
                        : u,
              )
              .toList();
      notifyListeners();
    }

    try {
      final result = await _performDocumentUpload(
        filePath,
        title,
        category: category,
        studySpaceId: studySpaceId,
        onUploaded: (id) {
          update(
            'Saved securely. Preparing your summary…',
            UploadStatus.running,
            documentId: id,
          );
          if (!_disposed && generation == _session && owner == user?.id) {
            unawaited(refreshDocuments());
          }
        },
        onStage: (stage) {
          update(stage, UploadStatus.running);
          if (!_disposed && generation == _session && owner == user?.id) {
            onStage?.call(stage);
          }
        },
      );
      update(
        result == 'READY'
            ? 'Ready to read and ask questions.'
            : result == 'PROCESSING_PENDING'
            ? 'Saved securely. AI is temporarily unavailable. Folio will resume the summary automatically when you reopen it.'
            : 'Saved securely. Some pages need review before we can summarise them.',
        result == 'READY' ? UploadStatus.ready : UploadStatus.needsReview,
      );
      return result;
    } catch (error) {
      update(
        error is ApiException
            ? error.message
            : 'Upload interrupted. Check your connection and try again.',
        UploadStatus.failed,
      );
      rethrow;
    }
  }

  Future<String> _performDocumentUpload(
    String filePath,
    String title, {
    String category = 'Document',
    ValueChanged<String>? onStage,
    ValueChanged<String>? onUploaded,
    String? studySpaceId,
  }) async {
    final generation = _session;
    final result = await api.uploadDocument(
      filePath: filePath,
      title: title,
      category: category,
      onStage: onStage,
      onUploaded: (id) {
        if (!_disposed && generation == _session) onUploaded?.call(id);
        if (_disposed || generation != _session || studySpaceId == null) return;
        final index = studySpaces.indexWhere(
          (space) => space.id == studySpaceId,
        );
        if (index < 0) return;
        studySpaces[index] = studySpaces[index].copyWith(
          documentIds: {...studySpaces[index].documentIds, id}.toList(),
        );
        unawaited(persistWorkspace());
        notifyListeners();
      },
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

  void startDocumentProcessing(String documentId, String title) {
    if (_disposed ||
        user == null ||
        documentUploads.any((u) => u.documentId == documentId && u.isRunning)) {
      return;
    }
    unawaited(_runDocumentProcessing(documentId, title));
  }

  void _resumePendingDocumentProcessing() {
    if (_disposed || user == null || appLocked) return;
    final pending =
        documents
            .where((document) {
              if (document.status == 'Awaiting processing' ||
                  document.status == 'Analyzing') {
                return true;
              }
              return document.status == 'Needs review' &&
                  document.summary.toLowerCase().contains(
                    'ai summarisation is temporarily unavailable',
                  );
            })
            .where((document) {
              return !_automaticProcessingAttempted.contains(document.id) &&
                  !documentUploads.any(
                    (upload) =>
                        upload.documentId == document.id && upload.isRunning,
                  );
            })
            .firstOrNull;
    if (pending == null) return;
    _automaticProcessingAttempted.add(pending.id);
    unawaited(_runDocumentProcessing(pending.id, pending.title));
  }

  Future<void> _runDocumentProcessing(String documentId, String title) async {
    final generation = _session;
    final owner = user?.id;
    final upload = DocumentUpload(
      id: ++_nextUploadId,
      filePath: '',
      title: title,
      category: 'Document',
      documentId: documentId,
      stage: 'Preparing your summary…',
    );
    documentUploads = [...documentUploads, upload];
    notifyListeners();
    void update(String stage, UploadStatus status) {
      if (_disposed || generation != _session || user?.id != owner) return;
      documentUploads =
          documentUploads
              .map((u) => u.id == upload.id ? u.update(stage, status) : u)
              .toList();
      notifyListeners();
    }

    try {
      final result = await api.processDocumentAutomatically(
        documentId,
        onStage: (stage) => update(stage, UploadStatus.running),
      );
      if (_disposed || generation != _session || user?.id != owner) return;
      await refreshDocuments();
      update(
        result == 'READY'
            ? 'Ready to read and ask questions.'
            : result == 'PROCESSING_PENDING'
            ? 'Saved securely. AI is temporarily unavailable. Folio will resume the summary automatically when you reopen it.'
            : 'Saved securely. Open the document to review its processing status.',
        result == 'READY' ? UploadStatus.ready : UploadStatus.needsReview,
      );
    } catch (error) {
      update(
        error is ApiException
            ? error.message
            : 'Could not finish the summary. Try again later.',
        UploadStatus.failed,
      );
    }
  }

  void toggleFavoriteDocument(String id) {
    if (user == null || !documents.any((d) => d.id == id)) return;
    if (!favoriteDocumentIds.remove(id)) favoriteDocumentIds.add(id);
    unawaited(persistWorkspace());
    notifyListeners();
  }

  Future<void> updateDocumentMetadata(
    Document doc,
    String title,
    String category,
  ) async {
    final generation = _session;
    await api.updateDocument(doc.id, title, category);
    if (generation != _session) return;
    final index = documents.indexWhere((d) => d.id == doc.id);
    if (index < 0) return;
    final renamed = Document.fromJson({
      ...documents[index].toJson(),
      'title': title.trim(),
      'type': category.trim(),
    });
    documents[index] = renamed;
    if (selectedDoc?.id == doc.id) selectedDoc = renamed;
    studyNotes =
        studyNotes
            .map(
              (n) =>
                  n.documentId == doc.id
                      ? StudyNote.fromJson({
                        ...n.toJson(),
                        'documentTitle': title.trim(),
                      })
                      : n,
            )
            .toList();
    studyCards =
        studyCards
            .map(
              (c) =>
                  c.documentId == doc.id
                      ? StudyCard.fromJson({
                        ...c.toJson(),
                        'documentTitle': title.trim(),
                      })
                      : c,
            )
            .toList();
    _addAuditLog(
      'Document Updated',
      'Changed title and category for ${renamed.title}.',
      'Document',
    );
    unawaited(persistWorkspace());
    notifyListeners();
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
    final answerBuffer = StringBuffer();
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
        if (type == 'delta') answerBuffer.write('${event['text'] ?? ''}');
        if (type == 'replace') {
          answerBuffer.clear();
          answerBuffer.write('${event['text'] ?? ''}');
        }
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
        if (updates.elapsedMilliseconds >= 70 || type != 'delta') {
          answer = answerBuffer.toString();
          replace(
            ChatMessage(
              id: '$id-a',
              role: 'streaming',
              text: answer,
              sources: sources,
            ),
          );
          notifyListeners();
          updates.reset();
        }
      }
      if (!current()) return;
      answer = answerBuffer.toString();
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
      answer = answerBuffer.toString();
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
    final quizRequest = messages[index].quizRequest;
    messages.removeRange(index, messages.length);
    if (documentId != null &&
        (quizRequest != null || question == 'Quiz me on this document')) {
      await generateQuiz(
        documentId,
        count: quizRequest?.count ?? 5,
        difficulty: quizRequest?.difficulty ?? 'standard',
        focus: quizRequest?.focus ?? '',
      );
    } else {
      await sendChat(question, documentId: documentId);
    }
  }

  StudySpace createStudySpace(String name) {
    final clean = name.trim();
    if (clean.isEmpty || user == null) {
      throw const FormatException('Enter a name for this study space.');
    }
    final space = StudySpace(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: clean,
      createdAt: DateTime.now().toIso8601String(),
    );
    studySpaces.insert(0, space);
    unawaited(persistWorkspace());
    notifyListeners();
    return space;
  }

  void attachDocuments(String spaceId, Iterable<String> documentIds) {
    final index = studySpaces.indexWhere((space) => space.id == spaceId);
    if (index < 0) return;
    final validIds = documentIds.where(
      (id) => documents.any((doc) => doc.id == id),
    );
    studySpaces[index] = studySpaces[index].copyWith(
      documentIds: {...studySpaces[index].documentIds, ...validIds}.toList(),
    );
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void setStudyDocuments(String spaceId, Iterable<String> documentIds) {
    final index = studySpaces.indexWhere((space) => space.id == spaceId);
    if (index < 0) return;
    final validIds = documentIds.where(
      (id) => documents.any((doc) => doc.id == id),
    );
    studySpaces[index] = studySpaces[index].copyWith(
      documentIds: validIds.toSet().toList(),
    );
    unawaited(persistWorkspace());
    notifyListeners();
  }

  List<StudyNote> notesForSpace(String spaceId) =>
      studyNotes.where((note) => note.spaceId == spaceId).toList();

  StudyNote saveStudyNote({
    required String spaceId,
    required String title,
    required String body,
    required String documentId,
    int? sourcePage,
  }) {
    final space = studySpaces.where((item) => item.id == spaceId).firstOrNull;
    final document =
        documents.where((item) => item.id == documentId).firstOrNull;
    final cleanBody = body.trim();
    if (user == null ||
        space == null ||
        document == null ||
        cleanBody.isEmpty) {
      throw const FormatException('Choose a source and enter a note.');
    }
    attachDocuments(spaceId, [documentId]);
    final note = StudyNote(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      spaceId: spaceId,
      title: title.trim().isEmpty ? 'Study note' : title.trim(),
      body: cleanBody,
      documentId: document.id,
      documentTitle: document.title,
      sourcePage: sourcePage,
      createdAt: DateTime.now().toIso8601String(),
    );
    studyNotes.insert(0, note);
    unawaited(persistWorkspace());
    notifyListeners();
    return note;
  }

  void deleteStudyNote(String noteId) {
    studyNotes.removeWhere((note) => note.id == noteId);
    unawaited(persistWorkspace());
    notifyListeners();
  }

  Future<void> generateQuiz(
    String documentId, {
    int count = 5,
    String difficulty = 'standard',
    String focus = '',
  }) async {
    final document =
        documents.where((item) => item.id == documentId).firstOrNull;
    if (document == null ||
        document.status != 'Ready' ||
        user == null ||
        isChatBusy(documentId)) {
      return;
    }
    final generation = _session;
    final key = documentId;
    final request = Completer<void>();
    _requests[key] = request;
    _chatErrors.remove(key);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final messages = [...messagesFor(documentId)];
    messages.addAll([
      ChatMessage(
        id: '$id-q',
        role: 'user',
        text: 'Quiz me on this document',
        quizRequest: QuizRequest(
          count: count,
          difficulty: difficulty,
          focus: focus,
        ),
      ),
      ChatMessage(
        id: '$id-a',
        role: 'streaming',
        text: 'Building a source-based quiz…',
      ),
    ]);
    _chatByDocument[key] = messages;
    unawaited(persistWorkspace());
    notifyListeners();
    try {
      final quiz = await api.generateQuiz(
        documentId,
        abortTrigger: request.future,
        count: count,
        difficulty: difficulty,
        focus: focus,
      );
      if (_disposed ||
          generation != _session ||
          !identical(_requests[key], request)) {
        return;
      }
      final current = _chatByDocument[key];
      if (current == null || current.isEmpty) return;
      current[current.length - 1] = ChatMessage(
        id: '$id-a',
        role: 'assistant',
        text: 'Quick quiz · ${document.title}',
        quiz: quiz,
      );
      _addAuditLog(
        'Study Quiz Created',
        'Created a source-grounded quiz from ${document.title}.',
        'Study',
      );
    } catch (error) {
      if (_disposed ||
          generation != _session ||
          !identical(_requests[key], request)) {
        return;
      }
      final current = _chatByDocument[key];
      if (current != null && current.isNotEmpty) {
        current[current.length - 1] = ChatMessage(
          id: '$id-a',
          role: 'assistant',
          text:
              error is ApiException
                  ? error.message
                  : 'Folio could not make a quiz. Please try again.',
        );
        _chatErrors[key] = current.last.text;
      }
      if (error is ApiException && error.statusCode == 401) {
        _resetAccount();
        authStep = 'credentials';
        await api.clearSession();
        if (!_disposed) notifyListeners();
      }
    } finally {
      if (generation == _session && identical(_requests[key], request)) {
        _requests.remove(key);
        unawaited(persistWorkspace());
        notifyListeners();
      }
    }
  }

  void answerStudyQuestion(
    String documentId,
    String messageId,
    int questionIndex,
    int choiceIndex,
  ) {
    final messages = _chatByDocument[documentId];
    final messageIndex =
        messages?.indexWhere((item) => item.id == messageId) ?? -1;
    if (messages == null || messageIndex < 0) return;
    final message = messages[messageIndex];
    final quiz = message.quiz;
    if (quiz == null ||
        questionIndex < 0 ||
        questionIndex >= quiz.questions.length) {
      return;
    }
    final question = quiz.questions[questionIndex];
    if (question.selectedIndex != null ||
        choiceIndex < 0 ||
        choiceIndex >= question.options.length) {
      return;
    }
    final questions = [...quiz.questions];
    questions[questionIndex] = question.copyWith(selectedIndex: choiceIndex);
    messages[messageIndex] = message.copyWith(
      quiz: quiz.copyWith(
        questions: questions,
        completed: questions.every((item) => item.selectedIndex != null),
      ),
    );
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void renameStudySpace(String id, String name) {
    final index = studySpaces.indexWhere((s) => s.id == id);
    if (user == null || index < 0 || name.trim().isEmpty) return;
    studySpaces[index] = studySpaces[index].copyWith(name: name.trim());
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void deleteStudySpace(String id) {
    studySpaces.removeWhere((s) => s.id == id);
    studyNotes.removeWhere((n) => n.spaceId == id);
    studyCards.removeWhere((c) => c.spaceId == id);
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void updateStudyNote(String id, String title, String body) {
    final i = studyNotes.indexWhere((n) => n.id == id);
    if (user == null || i < 0 || body.trim().isEmpty) return;
    studyNotes[i] = studyNotes[i].copyWith(
      title: title.trim().isEmpty ? 'Study note' : title.trim(),
      body: body.trim(),
    );
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void restoreStudyNote(StudyNote note) {
    if (user == null ||
        !studySpaces.any((s) => s.id == note.spaceId) ||
        studyNotes.any((n) => n.id == note.id)) {
      return;
    }
    studyNotes.insert(0, note);
    unawaited(persistWorkspace());
    notifyListeners();
  }

  List<StudyCard> cardsForSpace(String id) =>
      studyCards.where((c) => c.spaceId == id).toList();
  StudyCard addStudyCard({
    required String spaceId,
    required String front,
    required String back,
    required String documentId,
    int? sourcePage,
    String sourceExcerpt = '',
  }) {
    final doc = documents.where((d) => d.id == documentId).firstOrNull;
    if (user == null ||
        doc == null ||
        !studySpaces.any((s) => s.id == spaceId) ||
        front.trim().isEmpty ||
        back.trim().isEmpty) {
      throw const FormatException(
        'Choose a source and enter both sides of your card.',
      );
    }
    final existing =
        studyCards
            .where(
              (c) =>
                  c.spaceId == spaceId &&
                  c.front == front.trim() &&
                  c.documentId == documentId,
            )
            .firstOrNull;
    if (existing != null) return existing;
    final card = StudyCard(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      spaceId: spaceId,
      front: front.trim(),
      back: back.trim(),
      documentId: documentId,
      documentTitle: doc.title,
      sourcePage: sourcePage,
      sourceExcerpt: sourceExcerpt,
    );
    studyCards.insert(0, card);
    unawaited(persistWorkspace());
    notifyListeners();
    return card;
  }

  void reviewStudyCard(String id, bool recalled, {DateTime? now}) {
    final i = studyCards.indexWhere((c) => c.id == id);
    if (user == null || i < 0) return;
    studyCards[i] = studyCards[i].reviewed(recalled, now ?? DateTime.now());
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void deleteStudyCard(String id) {
    studyCards.removeWhere((c) => c.id == id);
    unawaited(persistWorkspace());
    notifyListeners();
  }

  StudyProgress studyProgress(String spaceId) {
    final space = studySpaces.where((s) => s.id == spaceId).firstOrNull;
    var answered = 0, correct = 0, rounds = 0;
    for (final id in space?.documentIds ?? <String>[]) {
      for (final message in messagesFor(id)) {
        final quiz = message.quiz;
        if (quiz == null) continue;
        if (quiz.completed) rounds++;
        for (final q in quiz.questions) {
          if (q.selectedIndex == null) continue;
          answered++;
          if (q.selectedIndex == q.correctIndex) correct++;
        }
      }
    }
    return StudyProgress(answered, correct, rounds);
  }

  void retryMissedQuiz(String documentId, StudyQuiz quiz) {
    if (user == null ||
        isChatBusy(documentId) ||
        !documents.any((d) => d.id == documentId)) {
      return;
    }
    final missed =
        quiz.questions
            .where(
              (q) =>
                  q.selectedIndex != null && q.selectedIndex != q.correctIndex,
            )
            .map(
              (q) => StudyQuestion(
                prompt: q.prompt,
                options: q.options,
                correctIndex: q.correctIndex,
                explanation: q.explanation,
                sourceDocumentId: q.sourceDocumentId,
                sourceTitle: q.sourceTitle,
                sourceExcerpt: q.sourceExcerpt,
                sourcePage: q.sourcePage,
              ),
            )
            .toList();
    if (missed.isEmpty) return;
    _chatByDocument[documentId] = [
      ...messagesFor(documentId),
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        role: 'assistant',
        text: 'Practice your missed questions',
        quiz: StudyQuiz(questions: missed),
      ),
    ];
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void updateDeadline(Deadline task) {
    if (user == null || task.action.trim().isEmpty || task.dueDate == null) {
      return;
    }
    final i = deadlines.indexWhere((d) => d.id == task.id);
    if (i >= 0 && task.sourceKey == null && deadlines[i].sourceKey != null) {
      final original = deadlines[i];
      if (original.documentId == task.documentId) {
        task = Deadline(
          id: task.id,
          action: task.action,
          doc: task.doc,
          due: task.due,
          days: task.days,
          documentId: task.documentId,
          severity: task.severity,
          completed: task.completed,
          sourceKey: original.sourceKey,
          sourceText: original.sourceText,
          sourcePage: original.sourcePage,
        );
      } else {
        _dismissedDocumentDeadlines.add(original.sourceKey!);
      }
    }
    if (task.sourceKey != null) {
      _dismissedDocumentDeadlines.remove(task.sourceKey);
    }
    if (i < 0) {
      deadlines.add(task);
    } else {
      deadlines[i] = task;
    }
    unawaited(persistWorkspace());
    notifyListeners();
  }

  void deleteDeadline(int id) {
    final task = deadlines.where((d) => d.id == id).firstOrNull;
    if (task?.sourceKey != null) {
      _dismissedDocumentDeadlines.add(task!.sourceKey!);
    }
    deadlines.removeWhere((d) => d.id == id);
    unawaited(persistWorkspace());
    notifyListeners();
  }

  Future<void> _syncDocumentDeadlines() async {
    final generation = _session;
    final scan = ++_deadlineScan;
    final candidates = await _deadlineExtractor(List<Document>.of(documents));
    if (generation != _session || scan != _deadlineScan || _disposed) return;
    final activeDocuments = documents.map((d) => d.id).toSet();
    final existing =
        deadlines.map((d) => d.sourceKey).whereType<String>().toSet();
    deadlineDateReviews =
        candidates
            .where(
              (c) =>
                  activeDocuments.contains(c.documentId) &&
                  c.due == null &&
                  !existing.contains(c.sourceKey) &&
                  !_dismissedDocumentDeadlines.contains(c.sourceKey),
            )
            .toList();
    var nextId = DateTime.now().microsecondsSinceEpoch;
    var added = false;
    for (final candidate in candidates) {
      if (!activeDocuments.contains(candidate.documentId) ||
          candidate.due == null ||
          existing.contains(candidate.sourceKey) ||
          _dismissedDocumentDeadlines.contains(candidate.sourceKey)) {
        continue;
      }
      // A manually entered task for this same source, action and day already
      // represents the deadline; don't create a second one on refresh.
      if (deadlines.any(
        (d) =>
            d.documentId == candidate.documentId &&
            d.dueDate == candidate.due &&
            d.action.toLowerCase() == candidate.action.toLowerCase(),
      )) {
        continue;
      }
      deadlines.add(
        Deadline(
          id: nextId++,
          action: candidate.action,
          doc: candidate.title,
          documentId: candidate.documentId,
          due: candidate.due!.toIso8601String(),
          days: 0,
          severity: 'medium',
          sourceKey: candidate.sourceKey,
          sourceText: candidate.sourceText,
          sourcePage: candidate.page,
        ),
      );
      existing.add(candidate.sourceKey);
      added = true;
    }
    if (added) unawaited(persistWorkspace());
  }

  void acceptDocumentDeadline(
    DocumentDeadlineCandidate candidate,
    DateTime due,
  ) {
    if (deadlines.any((d) => d.sourceKey == candidate.sourceKey)) return;
    if (user == null || !documents.any((d) => d.id == candidate.documentId)) {
      return;
    }
    updateDeadline(
      Deadline(
        id: DateTime.now().microsecondsSinceEpoch,
        action: candidate.action,
        doc: candidate.title,
        documentId: candidate.documentId,
        due: DateTime(due.year, due.month, due.day).toIso8601String(),
        days: 0,
        severity: 'medium',
        sourceKey: candidate.sourceKey,
        sourceText: candidate.sourceText,
        sourcePage: candidate.page,
      ),
    );
    deadlineDateReviews.removeWhere((c) => c.sourceKey == candidate.sourceKey);
    notifyListeners();
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
    _resumePendingDocumentProcessing();
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
    if (auditLogs.length > 300) auditLogs.removeRange(300, auditLogs.length);
    unawaited(persistWorkspace());
  }

  @override
  void dispose() {
    flushWorkspace();
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
