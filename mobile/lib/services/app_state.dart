import 'package:flutter/foundation.dart';
import '../models/document.dart';
import '../models/seed_data.dart';

class AppState extends ChangeNotifier {
  // Auth
  String authStep = 'credentials'; // credentials | mfa | authenticated
  String email = 'alex.m@folio-student.app';

  // Documents
  List<Document> documents = List.from(seedDocuments);
  List<Document> deletedDocs = [];
  Document? selectedDoc;

  // Deadlines
  List<Deadline> deadlines = List.from(seedDeadlines);

  // Audit logs
  List<AuditEntry> auditLogs = List.from(seedAuditLogs);

  // AI Credits
  int monthlyFreeUsed = 7;
  final int monthlyFreeLimit = 25;
  int aiCredits = 18;

  // Chat
  List<ChatMessage> chatMessages = [
    const ChatMessage(
      role: 'assistant',
      text:
          'Hello! I am your secure Folio document assistant. I only pull details from files in your encrypted vault. What details do you need checked?',
    ),
  ];
  bool aiTyping = false;
  String chatInput = '';

  // Security toggles
  bool mfaEnabled = true;
  bool biometricEnabled = true;
  bool sharingEnabled = false;

  // Notifications
  int get pendingCount => deadlines.where((d) => !d.completed).length;

  void login() {
    authStep = 'authenticated';
    _addAuditLog(AuditEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      time: _nowStr(),
      actor: 'Alex M.',
      action: 'OIDC Session Started',
      detail: 'MFA Token Authorized via Secure SSO',
      category: 'Security',
    ));
    notifyListeners();
  }

  void logout() {
    authStep = 'credentials';
    notifyListeners();
  }

  void selectDoc(Document? doc) {
    selectedDoc = doc;
    if (doc != null) {
      _addAuditLog(AuditEntry(
        id: DateTime.now().millisecondsSinceEpoch,
        time: _nowStr(),
        actor: 'Alex M.',
        action: 'Document Viewed',
        detail: '${doc.title} (POPIA Audited Access)',
        category: 'Access',
      ));
    }
    notifyListeners();
  }

  void softDeleteDoc(Document doc) {
    documents.removeWhere((d) => d.id == doc.id);
    deletedDocs.add(doc);
    if (selectedDoc?.id == doc.id) selectedDoc = null;
    _addAuditLog(AuditEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      time: _nowStr(),
      actor: 'Alex M.',
      action: 'Document Deleted',
      detail: "'${doc.title}' moved to recycle bin",
      category: 'Document',
    ));
    notifyListeners();
  }

  void restoreDoc(Document doc) {
    deletedDocs.removeWhere((d) => d.id == doc.id);
    documents.add(doc);
    _addAuditLog(AuditEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      time: _nowStr(),
      actor: 'Alex M.',
      action: 'Document Restored',
      detail: "'${doc.title}' recovered from recycle bin",
      category: 'Document',
    ));
    notifyListeners();
  }

  void addDocument(Document doc) {
    documents.insert(0, doc);
    _addAuditLog(AuditEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      time: _nowStr(),
      actor: 'Alex M.',
      action: 'Upload Completed',
      detail: "Uploaded '${doc.title}' classified as ${doc.type}",
      category: 'Document',
    ));
    notifyListeners();
  }

  void resolveDeadline(int id) {
    final idx = deadlines.indexWhere((d) => d.id == id);
    if (idx != -1) {
      deadlines[idx].completed = true;
      _addAuditLog(AuditEntry(
        id: DateTime.now().millisecondsSinceEpoch,
        time: _nowStr(),
        actor: 'System Audit',
        action: 'Compliance Met',
        detail: "Fulfilled: '${deadlines[idx].action}'",
        category: 'Security',
      ));
      notifyListeners();
    }
  }

  bool get hasCredits =>
      monthlyFreeUsed < monthlyFreeLimit || aiCredits > 0;

  void sendChat(String question) {
    if (question.trim().isEmpty) return;
    if (!hasCredits) return;

    chatMessages = [...chatMessages, ChatMessage(role: 'user', text: question)];
    aiTyping = true;
    notifyListeners();

    if (monthlyFreeUsed < monthlyFreeLimit) {
      monthlyFreeUsed++;
    } else {
      aiCredits--;
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      final response = _buildResponse(question.toLowerCase());
      chatMessages = [...chatMessages, response];
      aiTyping = false;
      _addAuditLog(AuditEntry(
        id: DateTime.now().millisecondsSinceEpoch,
        time: _nowStr(),
        actor: 'Alex M.',
        action: 'AI Grounded Query',
        detail: 'Prompted: "${question.substring(0, question.length.clamp(0, 45))}..."',
        category: 'AI Queries',
      ));
      notifyListeners();
    });
  }

  ChatMessage _buildResponse(String q) {
    if (q.contains('draft') || q.contains('summary') || q.contains('interview') || q.contains('job')) {
      return const ChatMessage(
        role: 'assistant',
        text:
            'Based on your uploaded documents, here is a summary for your graduate application:\n\n(1) Government Funding Award Letter â€” R98,450 confirmed for 2026, demonstrating financial stability.\n(2) Merit Bursary Agreement â€” R32,000 scholarship requiring 75%+ average.\n(3) Fee Statement â€” Outstanding balance of R4,120 due 28 Feb 2026; clear this before interviews.',
        sourceDoc: 'Government Funding Award Letter â€” 2026',
        sourcePage: 1,
        sources: [
          {'doc': 'Government Funding Award Letter â€” 2026', 'detail': 'Page 1, Award Conditions'},
          {'doc': 'Merit Bursary Agreement â€” 2026', 'detail': 'Page 2, Scholarship criteria'},
          {'doc': 'Semester 1 Fee Statement', 'detail': 'Page 1, Outstanding balance'},
        ],
      );
    } else if (q.contains('bursary') || q.contains('renew') || q.contains('merit')) {
      return const ChatMessage(
        role: 'assistant',
        text:
            'According to Section 4 of your Merit Bursary Agreement, the bursary is valued at R32,000/year and is renewable. Submit your Semester 1 transcript and a signed renewal declaration before 02 August 2026.',
        sourceDoc: 'Merit Bursary Agreement â€” 2026',
        sourcePage: 2,
        sources: [
          {'doc': 'Merit Bursary Agreement â€” 2026', 'detail': 'Page 2, Section 4: Renewal Parameters'},
        ],
      );
    } else if (q.contains('fee') || q.contains('owe') || q.contains('balance') || q.contains('pay')) {
      return const ChatMessage(
        role: 'assistant',
        text:
            'Your Semester 1 Fee Statement shows total charges of R65,000 (R45k tuition, R12k residence, R8k meals) with R60,880 financial aid applied. Outstanding net balance: R4,120 due by 28 February 2026.',
        sourceDoc: 'Semester 1 Fee Statement',
        sourcePage: 1,
        sources: [
          {'doc': 'Semester 1 Fee Statement', 'detail': 'Page 1, Summary Ledger'},
        ],
      );
    } else if (q.contains('funding') || q.contains('award') || q.contains('condition')) {
      return const ChatMessage(
        role: 'assistant',
        text:
            'Your Government Funding Award Letter confirms R98,450 approved for 2026. Key conditions: maintain a 60% academic average and remain full-time registered. Submit proof of registration before 12 February 2026.',
        sourceDoc: 'Government Funding Award Letter â€” 2026',
        sourcePage: 1,
        sources: [
          {'doc': 'Government Funding Award Letter â€” 2026', 'detail': 'Page 1, Paragraph 3'},
        ],
      );
    }
    return const ChatMessage(
      role: 'assistant',
      text:
          'You have 3 upcoming obligations. Most urgent: submit proof of registration by 12 Feb 2026 (3 days). Your bursary renewal declaration is due 02 Aug 2026.',
      sourceDoc: 'Government Funding Award Letter â€” 2026',
      sourcePage: 1,
      sources: [
        {'doc': 'Government Funding Award Letter â€” 2026', 'detail': 'Page 1, Registration deadline'},
        {'doc': 'Merit Bursary Agreement â€” 2026', 'detail': 'Page 2, Renewal window'},
      ],
    );
  }

  void purchaseCredits(int amount) {
    aiCredits += amount;
    _addAuditLog(AuditEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      time: _nowStr(),
      actor: 'Alex M.',
      action: 'Credit Purchase',
      detail: 'Purchased $amount AI query credits',
      category: 'Security',
    ));
    notifyListeners();
  }

  void toggleMfa() {
    mfaEnabled = !mfaEnabled;
    notifyListeners();
  }

  void toggleBiometric() {
    biometricEnabled = !biometricEnabled;
    notifyListeners();
  }

  void toggleSharing() {
    sharingEnabled = !sharingEnabled;
    notifyListeners();
  }

  void _addAuditLog(AuditEntry entry) {
    auditLogs = [entry, ...auditLogs];
  }

  String _nowStr() {
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}, $h:$m';
  }
}
