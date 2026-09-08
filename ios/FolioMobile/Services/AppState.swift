import Foundation
import Combine

final class AppState: ObservableObject {
    // Auth
    @Published var authStep: String = "credentials" // credentials | mfa | authenticated
    @Published var email: String = "alex.m@folio-student.app"

    // Documents
    @Published var documents: [FolioDocument] = SeedData.documents
    @Published var deletedDocs: [FolioDocument] = []
    @Published var selectedDoc: FolioDocument? = nil

    // Deadlines
    @Published var deadlines: [Deadline] = SeedData.deadlines

    // Audit logs
    @Published var auditLogs: [AuditEntry] = SeedData.auditLogs

    // AI Credits
    @Published var monthlyFreeUsed: Int = 7
    let monthlyFreeLimit: Int = 25
    @Published var aiCredits: Int = 18

    // Chat
    @Published var chatMessages: [ChatMessage] = [
        ChatMessage(role: "assistant", text: "Hello! I am your secure Folio document assistant. I only pull details from files in your encrypted vault. What details do you need checked?")
    ]
    @Published var aiTyping: Bool = false

    // Security toggles
    @Published var mfaEnabled: Bool = true
    @Published var biometricEnabled: Bool = true
    @Published var sharingEnabled: Bool = false

    var pendingCount: Int { deadlines.filter { !$0.completed }.count }
    var hasCredits: Bool { monthlyFreeUsed < monthlyFreeLimit || aiCredits > 0 }

    func login() {
        authStep = "authenticated"
        addAuditLog(AuditEntry(
            id: Int(Date().timeIntervalSince1970 * 1000),
            time: nowStr(),
            actor: "Alex M.",
            action: "OIDC Session Started",
            detail: "MFA Token Authorized via Secure SSO",
            category: "Security"
        ))
    }

    func logout() {
        authStep = "credentials"
    }

    func selectDoc(_ doc: FolioDocument?) {
        selectedDoc = doc
        if let doc = doc {
            addAuditLog(AuditEntry(
                id: Int(Date().timeIntervalSince1970 * 1000),
                time: nowStr(),
                actor: "Alex M.",
                action: "Document Viewed",
                detail: "\(doc.title) (POPIA Audited Access)",
                category: "Access"
            ))
        }
    }

    func softDeleteDoc(_ doc: FolioDocument) {
        documents.removeAll { $0.id == doc.id }
        deletedDocs.append(doc)
        if selectedDoc?.id == doc.id { selectedDoc = nil }
        addAuditLog(AuditEntry(
            id: Int(Date().timeIntervalSince1970 * 1000),
            time: nowStr(),
            actor: "Alex M.",
            action: "Document Deleted",
            detail: "'\(doc.title)' moved to recycle bin",
            category: "Document"
        ))
    }

    func restoreDoc(_ doc: FolioDocument) {
        deletedDocs.removeAll { $0.id == doc.id }
        documents.append(doc)
        addAuditLog(AuditEntry(
            id: Int(Date().timeIntervalSince1970 * 1000),
            time: nowStr(),
            actor: "Alex M.",
            action: "Document Restored",
            detail: "'\(doc.title)' recovered from recycle bin",
            category: "Document"
        ))
    }

    func addDocument(_ doc: FolioDocument) {
        documents.insert(doc, at: 0)
        addAuditLog(AuditEntry(
            id: Int(Date().timeIntervalSince1970 * 1000),
            time: nowStr(),
            actor: "Alex M.",
            action: "Upload Completed",
            detail: "Uploaded '\(doc.title)' classified as \(doc.type)",
            category: "Document"
        ))
    }

    func resolveDeadline(_ id: Int) {
        guard let idx = deadlines.firstIndex(where: { $0.id == id }) else { return }
        deadlines[idx].completed = true
        addAuditLog(AuditEntry(
            id: Int(Date().timeIntervalSince1970 * 1000),
            time: nowStr(),
            actor: "System Audit",
            action: "Compliance Met",
            detail: "Fulfilled: '\(deadlines[idx].action)'",
            category: "Security"
        ))
    }

    func sendChat(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, hasCredits else { return }

        chatMessages.append(ChatMessage(role: "user", text: trimmed))
        aiTyping = true

        if monthlyFreeUsed < monthlyFreeLimit {
            monthlyFreeUsed += 1
        } else {
            aiCredits -= 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }
            let response = self.buildResponse(trimmed.lowercased())
            self.chatMessages.append(response)
            self.aiTyping = false
            let clipped = String(trimmed.prefix(45))
            self.addAuditLog(AuditEntry(
                id: Int(Date().timeIntervalSince1970 * 1000),
                time: self.nowStr(),
                actor: "Alex M.",
                action: "AI Grounded Query",
                detail: "Prompted: \"\(clipped)...\"",
                category: "AI Queries"
            ))
        }
    }

    private func buildResponse(_ q: String) -> ChatMessage {
        if q.contains("draft") || q.contains("summary") || q.contains("interview") || q.contains("job") {
            return ChatMessage(
                role: "assistant",
                text: "Based on your uploaded documents, here is a summary for your graduate application:\n\n(1) Government Funding Award Letter — R98,450 confirmed for 2026, demonstrating financial stability.\n(2) Merit Bursary Agreement — R32,000 scholarship requiring 75%+ average.\n(3) Fee Statement — Outstanding balance of R4,120 due 28 Feb 2026; clear this before interviews.",
                sourceDoc: "Government Funding Award Letter — 2026",
                sourcePage: 1,
                sources: [
                    ChatSource(doc: "Government Funding Award Letter — 2026", detail: "Page 1, Award Conditions"),
                    ChatSource(doc: "Merit Bursary Agreement — 2026", detail: "Page 2, Scholarship criteria"),
                    ChatSource(doc: "Semester 1 Fee Statement", detail: "Page 1, Outstanding balance"),
                ]
            )
        } else if q.contains("bursary") || q.contains("renew") || q.contains("merit") {
            return ChatMessage(
                role: "assistant",
                text: "According to Section 4 of your Merit Bursary Agreement, the bursary is valued at R32,000/year and is renewable. Submit your Semester 1 transcript and a signed renewal declaration before 02 August 2026.",
                sourceDoc: "Merit Bursary Agreement — 2026",
                sourcePage: 2,
                sources: [
                    ChatSource(doc: "Merit Bursary Agreement — 2026", detail: "Page 2, Section 4: Renewal Parameters"),
                ]
            )
        } else if q.contains("fee") || q.contains("owe") || q.contains("balance") || q.contains("pay") {
            return ChatMessage(
                role: "assistant",
                text: "Your Semester 1 Fee Statement shows total charges of R65,000 (R45k tuition, R12k residence, R8k meals) with R60,880 financial aid applied. Outstanding net balance: R4,120 due by 28 February 2026.",
                sourceDoc: "Semester 1 Fee Statement",
                sourcePage: 1,
                sources: [
                    ChatSource(doc: "Semester 1 Fee Statement", detail: "Page 1, Summary Ledger"),
                ]
            )
        } else if q.contains("funding") || q.contains("award") || q.contains("condition") {
            return ChatMessage(
                role: "assistant",
                text: "Your Government Funding Award Letter confirms R98,450 approved for 2026. Key conditions: maintain a 60% academic average and remain full-time registered. Submit proof of registration before 12 February 2026.",
                sourceDoc: "Government Funding Award Letter — 2026",
                sourcePage: 1,
                sources: [
                    ChatSource(doc: "Government Funding Award Letter — 2026", detail: "Page 1, Paragraph 3"),
                ]
            )
        }
        return ChatMessage(
            role: "assistant",
            text: "You have 3 upcoming obligations. Most urgent: submit proof of registration by 12 Feb 2026 (3 days). Your bursary renewal declaration is due 02 Aug 2026.",
            sourceDoc: "Government Funding Award Letter — 2026",
            sourcePage: 1,
            sources: [
                ChatSource(doc: "Government Funding Award Letter — 2026", detail: "Page 1, Registration deadline"),
                ChatSource(doc: "Merit Bursary Agreement — 2026", detail: "Page 2, Renewal window"),
            ]
        )
    }

    func purchaseCredits(_ amount: Int) {
        aiCredits += amount
        addAuditLog(AuditEntry(
            id: Int(Date().timeIntervalSince1970 * 1000),
            time: nowStr(),
            actor: "Alex M.",
            action: "Credit Purchase",
            detail: "Purchased \(amount) AI query credits",
            category: "Security"
        ))
    }

    func toggleMfa() { mfaEnabled.toggle() }
    func toggleBiometric() { biometricEnabled.toggle() }
    func toggleSharing() { sharingEnabled.toggle() }

    private func addAuditLog(_ entry: AuditEntry) {
        auditLogs.insert(entry, at: 0)
    }

    private func nowStr() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, HH:mm"
        return formatter.string(from: now)
    }

    static func today() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: Date())
    }
}
