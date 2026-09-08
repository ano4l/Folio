import Foundation

enum SeedData {
    static let documents: [FolioDocument] = [
        FolioDocument(
            id: 1,
            title: "Government Funding Award Letter — 2026",
            type: "Funding Award Letter",
            date: "14 Jan 2026",
            pages: 3,
            status: "Ready",
            confidence: 96,
            summary: "Confirms full government funding for the 2026 academic year, covering tuition, accommodation, and a book allowance. Funding continues only if a 60% average is maintained and you remain registered full-time.",
            entities: [
                DocEntity(label: "Award amount", value: "R98,450"),
                DocEntity(label: "Condition", value: "Maintain 60% average"),
                DocEntity(label: "Action required", value: "Proof of registration by 12 Feb 2026"),
            ],
            rawText: "STUDENT FINANCIAL AID OFFICE. AWARD NOTIFICATION 2026.\nTotal Award Value: R98,450.\nConditions: Maintain 60% average, remain full-time registered.\nSubmit proof of registration within 30 days of term start."
        ),
        FolioDocument(
            id: 2,
            title: "Merit Bursary Agreement — 2026",
            type: "Bursary Agreement",
            date: "02 Feb 2026",
            pages: 5,
            status: "Ready",
            confidence: 91,
            summary: "Sets out a partial tuition bursary, renewable annually, conditional on submitting an updated academic transcript and a signed renewal declaration before 02 August 2026.",
            entities: [
                DocEntity(label: "Bursary value", value: "R32,000 / year"),
                DocEntity(label: "Renewal due", value: "02 Aug 2026"),
                DocEntity(label: "Requirement", value: "Transcript + signed declaration"),
            ],
            rawText: "ACADEMIC MERIT BURSARY SCHEME. AGREEMENT FORM 2026.\nValue: R32,000 per annum.\nRenewal deadline: 02 August 2026.\nRequirements: Transcript with 75%+ average and signed declaration."
        ),
        FolioDocument(
            id: 3,
            title: "Semester 1 Fee Statement",
            type: "Fee Statement",
            date: "20 Jan 2026",
            pages: 2,
            status: "Ready",
            confidence: 98,
            summary: "Itemises tuition, residence and meal plan charges for Semester 1, less the financial aid payment already received. An outstanding balance of R4,120 is due before 28 February 2026.",
            entities: [
                DocEntity(label: "Balance due", value: "R4,120"),
                DocEntity(label: "Due date", value: "28 Feb 2026"),
            ],
            rawText: "STUDENT ACCOUNTS & FINANCE. SEMESTER 1 STATEMENT.\nTuition: R45,000. Residence: R12,000. Meal plan: R8,000.\nTotal: R65,000. Less financial aid: R60,880.\nNET BALANCE DUE: R4,120. Due: 28 February 2026."
        ),
        FolioDocument(
            id: 4,
            title: "Bank Account Confirmation Letter",
            type: "Bank Letter",
            date: "11 Jan 2026",
            pages: 1,
            status: "Ready",
            confidence: 99,
            summary: "Confirms the student's account details for financial aid disbursement purposes. Verification status is fully completed and cleared.",
            entities: [
                DocEntity(label: "Purpose", value: "Disbursement verification"),
            ],
            rawText: "FOLIO PARTNER BANK. CLIENT ACCOUNT VERIFICATION LETTER.\nDate: 11 January 2026.\nWe confirm the registered student holds an active account authorized for financial aid disbursements. No restrictions apply."
        ),
    ]

    static let deadlines: [Deadline] = [
        Deadline(id: 1, action: "Submit proof of registration", doc: "Government Funding Award Letter — 2026", due: "12 Feb 2026", days: 3, severity: "high"),
        Deadline(id: 2, action: "Submit transcript & renewal declaration", doc: "Merit Bursary Agreement — 2026", due: "02 Aug 2026", days: 9, severity: "medium"),
        Deadline(id: 3, action: "Settle outstanding balance", doc: "Semester 1 Fee Statement", due: "28 Feb 2026", days: 14, severity: "low"),
    ]

    static let auditLogs: [AuditEntry] = [
        AuditEntry(id: 1, time: "24 Jul 2026, 09:12", actor: "Alex M.", action: "Document Viewed", detail: "Government Funding Award Letter — 2026 (POPIA Audited Access)", category: "Access"),
        AuditEntry(id: 2, time: "23 Jul 2026, 18:41", actor: "Alex M.", action: "AI Grounded Query", detail: "Asked: 'When is my bursary renewal due?'", category: "AI Queries"),
        AuditEntry(id: 3, time: "20 Jul 2026, 08:03", actor: "Security Service", action: "AES-256 Rotation", detail: "Encrypted at rest: Semester 1 Fee Statement (AWS S3-SSE KMS)", category: "Security"),
        AuditEntry(id: 4, time: "14 Jan 2026, 14:55", actor: "Alex M.", action: "Document Uploaded", detail: "Government Funding Award Letter — 2026 (Classified and summarised)", category: "Document"),
        AuditEntry(id: 5, time: "14 Jan 2026, 14:50", actor: "OIDC Identity System", action: "Secure SSO Login", detail: "MFA Token Authorized via OAuth 2.0 (Folio Student SSO Portal)", category: "Security"),
    ]
}
