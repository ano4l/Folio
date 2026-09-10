import Foundation

struct DocEntity: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let value: String
}

struct FolioDocument: Identifiable, Hashable {
    let id: Int
    var title: String
    var type: String
    var date: String
    var pages: Int
    var status: String
    var confidence: Int
    var summary: String
    var entities: [DocEntity]
    var rawText: String
}

struct Deadline: Identifiable, Hashable {
    let id: Int
    var action: String
    var doc: String
    var due: String
    var days: Int
    var severity: String // "high" | "medium" | "low"
    var completed: Bool = false
}

struct AuditEntry: Identifiable, Hashable {
    let id: Int
    var time: String
    var actor: String
    var action: String
    var detail: String
    var category: String // "Access" | "AI Queries" | "Security" | "Document"
}

struct ChatSource: Hashable {
    let doc: String
    let detail: String
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let role: String // "user" | "assistant"
    let text: String
    var sourceDoc: String? = nil
    var sourcePage: Int? = nil
    var sources: [ChatSource] = []
}
