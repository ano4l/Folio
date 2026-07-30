"use client";

import { useMemo, useState, useEffect, useRef } from "react";
import {
  AlertTriangle,
  Bell,
  ChevronRight,
  Clock3,
  FileText,
  FolderOpen,
  LayoutDashboard,
  LockKeyhole,
  LogOut,
  MessageSquareText,
  Search,
  Send,
  ShieldCheck,
  Sparkles,
  UploadCloud,
  X,
  CheckCircle,
  Eye,
  Download,
  Fingerprint,
  RotateCw,
  Clock,
  ArrowRight,
  UserCheck,
  AlertCircle,
  FileJson,
  CheckSquare
} from "lucide-react";

type DocType = "NSFAS Award Letter" | "Bursary Agreement" | "Fee Statement" | "Bank Letter" | "Appeal Correspondence";

type DocEntity = {
  label: string;
  value: string;
  bbox?: { top: number; left: number; width: number; height: number }; // Simulated document bounding box for mapping hover effects
};

type Document = {
  id: number;
  title: string;
  type: DocType;
  date: string;
  pages: number;
  status: "Ready" | "Uploading" | "Scanning" | "Analyzing" | "Error";
  confidence: number;
  summary: string;
  entities: DocEntity[];
  rawText?: string;
};

type Screen = "dashboard" | "documents" | "ask" | "deadlines" | "security";

type LogCategory = "All" | "Access" | "Document" | "Security" | "AI Queries";

type AuditEntry = {
  id: number;
  time: string;
  actor: string;
  action: string;
  detail: string;
  category: LogCategory;
};

const typeStyles: Record<DocType, { label: string; color: string; tint: string; border: string }> = {
  "NSFAS Award Letter": { label: "NSFAS", color: "#c97a2b", tint: "#fbede0", border: "#f3dbca" },
  "Bursary Agreement": { label: "Bursary", color: "#0e7c74", tint: "#e4f2f0", border: "#cbe3e0" },
  "Fee Statement": { label: "Fees", color: "#33455e", tint: "#e8ecf1", border: "#ced5de" },
  "Bank Letter": { label: "Bank", color: "#6e5a7e", tint: "#eee8f2", border: "#dbdae8" },
  "Appeal Correspondence": { label: "Appeal", color: "#b3432d", tint: "#fbe7e2", border: "#f3cfc6" },
};

const initialDocuments: Document[] = [
  {
    id: 1,
    title: "NSFAS Award Letter — 2026",
    type: "NSFAS Award Letter",
    date: "14 Jan 2026",
    pages: 3,
    status: "Ready",
    confidence: 96,
    summary: "Confirms full NSFAS funding for the 2026 academic year, covering tuition, accommodation, and a book allowance. Funding continues only if a 60% average is maintained and you remain registered full-time. Proof of registration must be submitted within 30 days of the start of term.",
    entities: [
      { label: "Award amount", value: "R98,450", bbox: { top: 22, left: 62, width: 22, height: 6 } },
      { label: "Condition", value: "Maintain 60% average", bbox: { top: 41, left: 15, width: 32, height: 6 } },
      { label: "Action required", value: "Proof of registration by 12 Feb 2026", bbox: { top: 62, left: 15, width: 55, height: 6 } }
    ],
    rawText: "REPUBLIC OF SOUTH AFRICA. NSFAS FINANCIAL AID OFFICE. London office. 14 January 2026. Ref: SAF-2026-9921. Dear Londiwe Mahlangu, We are pleased to inform you that your NSFAS Award for the academic year 2026 has been approved. The full award amount is R98,450, covering tuition fees, registered accommodation fees, and a study material allowance. Conditions of award: 1. Maintain an academic progress average of 60% or higher across all registered modules. 2. Remain registered as a full-time student in an accredited program (BSc Software Engineering). 3. Action Required: Please submit formal Proof of Registration (POR) from your institution to the bursary office before 12 February 2026."
  },
  {
    id: 2,
    title: "Eduvos Merit Bursary Agreement",
    type: "Bursary Agreement",
    date: "02 Feb 2026",
    pages: 5,
    status: "Ready",
    confidence: 91,
    summary: "Sets out a partial tuition bursary, renewable annually, conditional on submitting an updated academic transcript and a signed renewal declaration before the renewal window closes on 02 August 2026.",
    entities: [
      { label: "Bursary value", value: "R32,000 / year", bbox: { top: 25, left: 58, width: 25, height: 6 } },
      { label: "Renewal due", value: "02 Aug 2026", bbox: { top: 48, left: 15, width: 20, height: 6 } },
      { label: "Requirement", value: "Transcript + signed declaration", bbox: { top: 68, left: 15, width: 45, height: 6 } }
    ],
    rawText: "EDUVOS ACADEMIC MERIT BURSARY SCHEME. AGREEMENT FORM 2026. This document binds the scholar and the institution. Value of benefit: R32,000 per annum, directly credited to tuition. Renewal parameters: Student must make application for renewal before 02 August 2026. Requirements for submission: Must attach formal transcript showing average grade above 75%, and a completed, signed renewal declaration form."
  },
  {
    id: 3,
    title: "Semester 1 Fee Statement",
    type: "Fee Statement",
    date: "20 Jan 2026",
    pages: 2,
    status: "Ready",
    confidence: 98,
    summary: "Itemises tuition, residence and meal plan charges for Semester 1, less the NSFAS payment already received. An outstanding balance is due before the exam period begins on 28 February 2026.",
    entities: [
      { label: "Balance due", value: "R4,120", bbox: { top: 78, left: 62, width: 18, height: 6 } },
      { label: "Due date", value: "28 Feb 2026", bbox: { top: 52, left: 55, width: 20, height: 6 } }
    ],
    rawText: "EDUVOS DEPOSIT SLIP & STATEMENT. Student Number: 2026-LM. Name: Londiwe Mahlangu. Semester 1 ledger items: Tuition: R45,000. Residence: R12,000. Meal plan: R8,000. Total Charges: R65,000. Less: NSFAS disbursement credit (R60,880). NET BALANCE DUE: R4,120. Due Date: 28 February 2026. Outstanding amounts must be settled before exam entrance permits are generated."
  },
  {
    id: 4,
    title: "Standard Bank Account Confirmation",
    type: "Bank Letter",
    date: "11 Jan 2026",
    pages: 1,
    status: "Ready",
    confidence: 99,
    summary: "Confirms the student's account details for NSFAS disbursement purposes. Verification status is fully completed and cleared with no pending liabilities.",
    entities: [
      { label: "Purpose", value: "Disbursement verification", bbox: { top: 35, left: 15, width: 40, height: 6 } }
    ],
    rawText: "STANDARD BANK OF SOUTH AFRICA LIMITED. CLIENT ACCOUNT VERIFICATION LETTER. Date: 11 January 2026. To whom it may concern, We confirm that Londiwe Mahlangu holds active transactional account number 1092-2292-192 with our campus branch. This account is validated and authorized for NSFAS disbursement deposit credits. No restrictions apply."
  },
];

const initialDeadlines = [
  { id: 1, action: "Submit proof of registration", doc: "NSFAS Award Letter — 2026", due: "12 Feb 2026", days: 3, severity: "high", completed: false },
  { id: 2, action: "Submit transcript & renewal declaration", doc: "Eduvos Merit Bursary Agreement", due: "02 Aug 2026", days: 9, severity: "medium", completed: false },
  { id: 3, action: "Settle outstanding balance", doc: "Semester 1 Fee Statement", due: "28 Feb 2026", days: 14, severity: "low", completed: false },
];

const initialAuditLogs: AuditEntry[] = [
  { id: 1, time: "24 Jul 2026, 09:12", actor: "Londiwe M.", action: "Document Viewed", detail: "NSFAS Award Letter — 2026 (POPIA Audited Access)", category: "Access" },
  { id: 2, time: "23 Jul 2026, 18:41", actor: "Londiwe M.", action: "AI Grounded Query", detail: "Asked: 'When is my bursary renewal due?'", category: "AI Queries" },
  { id: 3, time: "20 Jul 2026, 08:03", actor: "Security Service", action: "AES-256 Rotation", detail: "Encrypted at rest: Semester 1 Fee Statement (AWS S3-SSE KMS)", category: "Security" },
  { id: 4, time: "14 Jan 2026, 14:55", actor: "Londiwe M.", action: "Document Uploaded", detail: "NSFAS Award Letter — 2026 (Classified and summarised)", category: "Document" },
  { id: 5, time: "14 Jan 2026, 14:50", actor: "OIDC Identity System", action: "Secure SSO Login", detail: "MFA Token Authorized via OAuth 2.0 (Eduvos Student SSO Portal)", category: "Security" },
];

const navItems = [
  ["dashboard", "Dashboard", LayoutDashboard],
  ["documents", "Documents", FileText],
  ["ask", "Ask AI", MessageSquareText],
  ["deadlines", "Deadlines", Clock3],
  ["security", "Security", ShieldCheck],
] as const;

export default function FolioApp() {
  // Authentication & MFA flow states
  const [authStep, setAuthStep] = useState<"credentials" | "mfa" | "authenticated">("credentials");
  const [emailInput, setEmailInput] = useState("londiwe.m@eduvos-student.ac.za");
  const [passwordInput, setPasswordInput] = useState("••••••••••••");
  const [mfaDigits, setMfaDigits] = useState<string[]>(["", "", "", "", "", ""]);
  const [mfaError, setMfaError] = useState("");
  const [mfaTimer, setMfaTimer] = useState(59);
  const [isResending, setIsResending] = useState(false);
  const mfaRefs = useRef<(HTMLInputElement | null)[]>([]);

  // Navigation, documents, and interactive highlights
  const [screen, setScreen] = useState<Screen>("dashboard");
  const [documents, setDocuments] = useState<Document[]>(initialDocuments);
  const [selectedDoc, setSelectedDoc] = useState<Document | null>(null);
  const [hoveredEntity, setHoveredEntity] = useState<DocEntity | null>(null);
  const [docTab, setDocTab] = useState<"preview" | "ocr" | "json">("preview");

  // Mobile layout states
  const [mobileDetailTab, setMobileDetailTab] = useState<"extraction" | "document">("extraction");
  const [mobileProfileOpen, setMobileProfileOpen] = useState(false);

  // Upload state machine
  const [uploadOpen, setUploadOpen] = useState(false);
  const [uploadTitle, setUploadTitle] = useState("");
  const [uploadType, setUploadType] = useState<DocType>("Fee Statement");
  const [uploadProgress, setUploadProgress] = useState<number>(0);
  const [uploadStep, setUploadStep] = useState<"idle" | "uploading" | "ocr" | "nlp" | "done">("idle");

  // Deadlines & Timeline interactive state
  const [deadlines, setDeadlines] = useState(initialDeadlines);
  const [completingDeadlineId, setCompletingDeadlineId] = useState<number | null>(null);

  // Security and Audit log search/filter states
  const [sharing, setSharing] = useState(false);
  const [logFilter, setLogFilter] = useState<LogCategory>("All");
  const [logSearch, setLogSearch] = useState("");
  const [auditLogs, setAuditLogs] = useState<AuditEntry[]>(initialAuditLogs);

  // Grounded Chat Q&A states
  const [chatInput, setInput] = useState("");
  const [chatMessages, setMessages] = useState<Array<{ role: "assistant" | "user"; text: string; sourceDoc?: string; sourcePage?: number; sources?: { doc: string; detail: string }[] }>>([
    {
      role: "assistant",
      text: "Hello Londiwe. I am your secure Folio document assistant. I only pull details from files in your encrypted vault. What details do you need checked?",
    },
  ]);
  const [aiTyping, setAiTyping] = useState(false);

  // Toasts
  const [toast, setToast] = useState("");

  // Auto clear toast
  useEffect(() => {
    if (toast) {
      const t = setTimeout(() => setToast(""), 4000);
      return () => clearTimeout(t);
    }
  }, [toast]);

  // MFA code resend countdown
  useEffect(() => {
    if (authStep === "mfa" && mfaTimer > 0) {
      const countdown = setInterval(() => setMfaTimer((t) => t - 1), 1000);
      return () => clearInterval(countdown);
    }
  }, [authStep, mfaTimer]);

  const initials = (name: string) => {
    return name.split(" ").map((n) => n[0]).join("").slice(0, 2).toUpperCase();
  };

  const handleCredentialsSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setAuthStep("mfa");
    setMfaTimer(59);
    setMfaError("");
    setToast("MFA Passcode issued to registered student device.");
  };

  const handleMfaChange = (index: number, val: string) => {
    if (!/^[0-9]?$/.test(val)) return;
    const nextMfa = [...mfaDigits];
    nextMfa[index] = val;
    setMfaDigits(nextMfa);

    // Auto-focus next input
    if (val && index < 5) {
      mfaRefs.current[index + 1]?.focus();
    }
  };

  const handleMfaKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Backspace" && !mfaDigits[index] && index > 0) {
      const nextMfa = [...mfaDigits];
      nextMfa[index - 1] = "";
      setMfaDigits(nextMfa);
      mfaRefs.current[index - 1]?.focus();
    }
  };

  const handleVerifyMfa = () => {
    const code = mfaDigits.join("");
    if (code.length < 6) {
      setMfaError("Please fill out the full 6-digit verification security code.");
      return;
    }
    // Simulation: Correct code is 123456 or any code for testing
    if (code === "123456" || code === "000000" || true) {
      setAuthStep("authenticated");
      setToast("Authorized. Welcome to Folio Student Portal.");
      // Log Secure Session Initiation
      const newLog: AuditEntry = {
        id: Date.now(),
        time: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }) + ", " + new Date().toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" }),
        actor: "Londiwe M.",
        action: "OIDC Session Started",
        detail: "MFA Token Authorized via Secure SSO (IP: 192.168.1.182, Location: Eduvos Campus)",
        category: "Security"
      };
      setAuditLogs((prev) => [newLog, ...prev]);
    } else {
      setMfaError("Invalid verification code. Please request a new token or retry.");
    }
  };

  const handleResendMfa = () => {
    setIsResending(true);
    setTimeout(() => {
      setMfaTimer(59);
      setMfaDigits(["", "", "", "", "", ""]);
      setMfaError("");
      setIsResending(false);
      setToast("A fresh 6-digit secure key has been dispatched via OAuth SMS.");
    }, 1200);
  };

  // Upload Simulation State Machine
  const handleUploadSubmit = () => {
    if (!uploadTitle.trim()) {
      setToast("Please state a clear document title for classification.");
      return;
    }

    setUploadStep("uploading");
    setUploadProgress(15);

    // Tick progress bar
    const progressTimer = setInterval(() => {
      setUploadProgress((p) => {
        if (p >= 95) {
          clearInterval(progressTimer);
          return 95;
        }
        return p + Math.floor(Math.random() * 20) + 5;
      });
    }, 200);

    // 1. Finished network upload (to simulated S3 bucket)
    setTimeout(() => {
      clearInterval(progressTimer);
      setUploadProgress(100);
      setUploadStep("ocr");
      setToast("File received. Extracting text via AWS Textract OCR...");

      // 2. Optical Character Recognition
      setTimeout(() => {
        setUploadStep("nlp");
        setToast("Running LayoutLM NLP classification & entity extraction...");

        // 3. AI Entity Mapping & Summary
        setTimeout(() => {
          const newDocId = Date.now();
          const parsedDoc: Document = {
            id: newDocId,
            title: uploadTitle,
            type: uploadType,
            date: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }),
            pages: Math.floor(Math.random() * 3) + 1,
            status: "Ready",
            confidence: Math.floor(Math.random() * 10) + 88,
            summary: `This is an officially processed ${uploadType}. Our system classified this document and ran extraction of crucial timelines, figures, and conditional clauses. The compliance confidence rate is optimal.`,
            entities: [
              { label: "Detected type", value: uploadType, bbox: { top: 15, left: 15, width: 35, height: 6 } },
              { label: "Verification Status", value: "Verified and Cleared", bbox: { top: 40, left: 15, width: 30, height: 6 } },
              { label: "System Confidence", value: "Grounded & Authenticated", bbox: { top: 65, left: 15, width: 45, height: 6 } },
            ],
            rawText: `STUDENT FINANCE DOCUMENT. PORTAL RETRIEVAL CLASSIFICATION. Date: ${new Date().toLocaleDateString("en-ZA")}. Classified as: ${uploadType}. All entities validated successfully under POPIA regulations.`
          };

          setDocuments((prev) => [parsedDoc, ...prev]);
          setUploadStep("done");
          setUploadOpen(false);
          setUploadTitle("");
          setToast("Document processed successfully! Extractions linked.");

          // Log Document Upload
          const newLog: AuditEntry = {
            id: Date.now(),
            time: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }) + ", " + new Date().toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" }),
            actor: "Londiwe M.",
            action: "Upload Completed",
            detail: `Uploaded '${uploadTitle}' classified as ${uploadType}. Metadata indexed into PostgreSQL.`,
            category: "Document"
          };
          setAuditLogs((prev) => [newLog, ...prev]);

          // Trigger a dynamic new deadline if it was an appeal or fee statement
          if (uploadType === "Appeal Correspondence") {
            const freshDeadline = {
              id: Date.now(),
              action: "Follow up on Appeal Correspondence",
              doc: uploadTitle,
              due: "Within 30 Days",
              days: 30,
              severity: "medium" as const,
              completed: false
            };
            setDeadlines((prev) => [freshDeadline, ...prev]);
          }

        }, 1500);
      }, 1500);
    }, 1500);
  };

  // Complete a deadline timeline item with state simulation
  const handleResolveDeadline = (id: number) => {
    setCompletingDeadlineId(id);
    setToast("Verifying completed action with database record...");

    setTimeout(() => {
      setDeadlines((prev) =>
        prev.map((d) => (d.id === id ? { ...d, completed: true } : d))
      );
      setCompletingDeadlineId(null);
      setToast("Task resolved! Database entry updated.");

      // Log Security Compliance Audit
      const targetDeadline = deadlines.find((d) => d.id === id);
      const newLog: AuditEntry = {
        id: Date.now(),
        time: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }) + ", " + new Date().toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" }),
        actor: "System Audit",
        action: "Compliance Met",
        detail: `Verification complete: Londiwe M. fulfilled action '${targetDeadline?.action}' associated with '${targetDeadline?.doc}'.`,
        category: "Security"
      };
      setAuditLogs((prev) => [newLog, ...prev]);
    }, 1500);
  };

  // AI QA Grounded responses logic
  const handleSendChat = (question = chatInput) => {
    if (!question.trim()) return;

    setMessages((prev) => [...prev, { role: "user", text: question }]);
    setInput("");
    setAiTyping(true);

    setTimeout(() => {
      const q = question.toLowerCase();
      let responseText = "";
      let matchedDoc = "NSFAS Award Letter — 2026";
      let matchedPage = 1;
      let citations: { doc: string; detail: string }[] = [];

      if (q.includes("bursary") || q.includes("renew") || q.includes("merit")) {
        responseText = "According to Section 4 of your Eduvos Merit Bursary Agreement, the bursary is valued at R32,000 per year and is renewable. You are required to submit your official Semester 1 transcript and a signed renewal declaration before 02 August 2026.";
        matchedDoc = "Eduvos Merit Bursary Agreement";
        matchedPage = 2;
        citations = [{ doc: "Eduvos Merit Bursary Agreement", detail: "Page 2, Section 4: Academic Transcript & Declaration Renewal Parameters" }];
      } else if (q.includes("fee") || q.includes("owe") || q.includes("statement") || q.includes("pay") || q.includes("balance")) {
        responseText = "Your Semester 1 Fee Statement records total charges of R65,000 (R45k tuition, R12k residence, R8k meals) with a NSFAS credit of R60,880 applied. You have an outstanding net balance of R4,120 due by 28 February 2026.";
        matchedDoc = "Semester 1 Fee Statement";
        matchedPage = 1;
        citations = [{ doc: "Semester 1 Fee Statement", detail: "Page 1, Summary Ledger: Tuition and Meals Net Balance calculations" }];
      } else if (q.includes("nsfas") || q.includes("average") || q.includes("condition") || q.includes("allowance")) {
        responseText = "Based on your NSFAS Award Letter (2026), your full funding of R98,450 is approved. Key conditions are: maintaining a 60% academic average grade and full-time registration status. You must submit your proof of registration before 12 February 2026.";
        matchedDoc = "NSFAS Award Letter — 2026";
        matchedPage = 1;
        citations = [{ doc: "NSFAS Award Letter — 2026", detail: "Page 1, Paragraph 3: Award Allocations and Registration proof timelines" }];
      } else {
        responseText = "Based on the documents in your secure vault, you currently have 3 upcoming tasks. The most urgent is submitting proof of registration for NSFAS by 12 February 2026 (3 days left). Your bursary renewal declaration is due 02 August 2026.";
        matchedDoc = "NSFAS Award Letter — 2026";
        matchedPage = 1;
        citations = [
          { doc: "NSFAS Award Letter — 2026", detail: "Page 1, Proof of Registration Submission parameters" },
          { doc: "Eduvos Merit Bursary Agreement", detail: "Page 2, Renewal Window Specifications" }
        ];
      }

      setMessages((prev) => [
        ...prev,
        { role: "assistant", text: responseText, sourceDoc: matchedDoc, sourcePage: matchedPage, sources: citations }
      ]);
      setAiTyping(false);

      // Log AI Query event
      const newLog: AuditEntry = {
        id: Date.now(),
        time: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }) + ", " + new Date().toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" }),
        actor: "Londiwe M.",
        action: "AI Grounded Query",
        detail: `Prompted: "${question.substring(0, 45)}...". Responded with verified citation: ${matchedDoc}`,
        category: "AI Queries"
      };
      setAuditLogs((prev) => [newLog, ...prev]);

    }, 1200);
  };

  // Export audit logs
  const handleExportLogs = () => {
    const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(auditLogs, null, 2));
    const downloadAnchor = document.createElement('a');
    downloadAnchor.setAttribute("href", dataStr);
    downloadAnchor.setAttribute("download", "folio_popia_compliance_audit_log.json");
    document.body.appendChild(downloadAnchor);
    downloadAnchor.click();
    downloadAnchor.remove();
    setToast("POPIA-compliant JSON security log download started.");
  };

  // Filter audit logs by category + search string
  const filteredAuditLogs = useMemo(() => {
    return auditLogs.filter((entry) => {
      const matchCategory = logFilter === "All" || entry.category === logFilter;
      const matchSearch = entry.action.toLowerCase().includes(logSearch.toLowerCase()) ||
                          entry.detail.toLowerCase().includes(logSearch.toLowerCase()) ||
                          entry.actor.toLowerCase().includes(logSearch.toLowerCase());
      return matchCategory && matchSearch;
    });
  }, [auditLogs, logFilter, logSearch]);


  // Login Screen render
  if (authStep === "credentials") {
    return (
      <main className="login-page">
        <div className="login-card">
          <div className="brand">
            <span><FolderOpen size={19} /></span>
            <div>
              <b>Folio</b>
              <small>Student financial documents understood.</small>
            </div>
          </div>
          <h1>Your funding paperwork, finally clear.</h1>
          <p>Securely store, analyze and act on every document that keeps your studies moving.</p>

          <form onSubmit={handleCredentialsSubmit} className="login-form">
            <label>
              Student Email Address
              <input
                type="email"
                value={emailInput}
                onChange={(e) => setEmailInput(e.target.value)}
                placeholder="e.g. name@eduvos-student.ac.za"
                required
              />
            </label>
            <label>
              Password
              <input
                type="password"
                value={passwordInput}
                onChange={(e) => setPasswordInput(e.target.value)}
                required
              />
            </label>

            <div className="mfa-notice">
              <ShieldCheck size={16} />
              <span>Multi-factor authentication via Eduvos Single Sign-On (OAuth 2.0 / OIDC) is enabled.</span>
            </div>

            <button type="submit" className="primary full">
              Sign in securely <ArrowRight size={15} style={{ marginLeft: 6 }} />
            </button>
          </form>

          <small className="login-foot">
            Protected under POPIA Act (Republic of South Africa). Your documents are encrypted at rest with military-grade AES-256 and in transit via TLS 1.3.
          </small>
        </div>
      </main>
    );
  }

  // MFA Verification Screen render
  if (authStep === "mfa") {
    return (
      <main className="login-page">
        <div className="login-card mfa-card">
          <div className="mfa-header">
            <span><Fingerprint size={28} style={{ color: "var(--teal)" }} /></span>
            <h2>Security MFA Code</h2>
            <p>We sent a 6-digit secure login token to your student device. Please enter it to authorize your session.</p>
          </div>

          <div className="mfa-digits-container">
            {mfaDigits.map((digit, i) => (
              <input
                key={i}
                ref={(el) => { mfaRefs.current[i] = el; }}
                type="text"
                maxLength={1}
                value={digit}
                onChange={(e) => handleMfaChange(i, e.target.value)}
                onKeyDown={(e) => handleMfaKeyDown(i, e)}
                placeholder="-"
                className="mfa-digit-input"
              />
            ))}
          </div>

          {mfaError && (
            <div className="mfa-error-message">
              <AlertCircle size={14} />
              <span>{mfaError}</span>
            </div>
          )}

          <button onClick={handleVerifyMfa} className="primary full" style={{ marginTop: 10 }}>
            Authorize Session
          </button>

          <div className="mfa-timer-row">
            {mfaTimer > 0 ? (
              <span className="mfa-countdown-text">Verification token expires in <b>{mfaTimer}s</b></span>
            ) : (
              <span className="mfa-countdown-expired">Token has expired.</span>
            )}

            <button
              onClick={handleResendMfa}
              disabled={mfaTimer > 0 || isResending}
              className="link resend-mfa-btn"
              style={{ opacity: mfaTimer > 0 ? 0.5 : 1 }}
            >
              {isResending ? <RotateCw className="spin" size={13} /> : "Resend Token"}
            </button>
          </div>

          <div className="demo-bypass-hint">
            <strong>Prototype Guide:</strong> For review purposes, enter any code or click <b>Authorize Session</b> to continue.
          </div>
        </div>
      </main>
    );
  }

  // Dashboard & Authenticated Core Application App shell
  return (
    <main className="app-shell animate-fade-in">
      {/* Sidebar Navigation */}
      <aside className="sidebar">
        <div className="brand">
          <span><FolderOpen size={17} /></span>
          <div>
            <b>Folio</b>
            <small>Financial documents understood</small>
          </div>
        </div>

        <nav>
          {navItems.map(([key, label, Icon]) => (
            <button
              className={screen === key || (screen === "documents" && selectedDoc && key === "documents") ? "active" : ""}
              key={key}
              onClick={() => {
                setScreen(key);
                setSelectedDoc(null);
              }}
            >
              <Icon size={16} />
              <span>{label}</span>
            </button>
          ))}
        </nav>

        <div className="sidebar-foot">
          <div className="profile">
            <span>LM</span>
            <div>
              <b>Londiwe Mahlangu</b>
              <small>BSc Software Engineering</small>
            </div>
          </div>
          <button onClick={() => setAuthStep("credentials")} className="signout-button">
            <LogOut size={16} />
            <span>Sign out</span>
          </button>
        </div>
      </aside>

      {/* Main Core Viewport */}
      <div className="main">
        {/* Top Header Row */}
        <header className="topbar">
          {/* Mobile Brand Row */}
          <div className="mobile-header-brand">
            <span><FolderOpen size={15} /></span>
            <b>Folio</b>
          </div>

          <div className="search desktop-only">
            <Search size={15} />
            <input placeholder="Search documents & extracted entities..." />
          </div>

          <div className="header-actions">
            <div className="popia-compliant-pill desktop-only">
              <ShieldCheck size={13} />
              <span>POPIA Secured</span>
            </div>

            <button className="notification">
              <Bell size={17} />
              <em />
            </button>

            {/* Profile Dropdown Trigger for Mobile & Desktop */}
            <div className="profile-header-chip" onClick={() => setMobileProfileOpen(!mobileProfileOpen)}>
              <span>LM</span>
              <div className="desktop-only">
                <b>Londiwe M.</b>
                <small>Student Account</small>
              </div>
            </div>

            {/* Quick Profile Sheet for Mobile/Desktop */}
            {mobileProfileOpen && (
              <div className="quick-profile-dropdown animate-slide-up">
                <div className="dropdown-profile-header">
                  <b>Londiwe Mahlangu</b>
                  <p>londiwe.m@eduvos-student.ac.za</p>
                  <small>BSc Software Engineering</small>
                </div>
                <button
                  className="dropdown-item signout"
                  onClick={() => {
                    setMobileProfileOpen(false);
                    setAuthStep("credentials");
                  }}
                >
                  <LogOut size={14} /> Sign out
                </button>
              </div>
            )}
          </div>
        </header>

        {/* Dynamic Screen Components */}
        <div className="content">
          {/* SCREEN: DASHBOARD */}
          {screen === "dashboard" && (
            <section className="screen">
              <div className="screen-heading">
                <div>
                  <label>Overview</label>
                  <h1>Welcome back, Londiwe</h1>
                  <p>Secure document extraction engine & retrieval assistant is active.</p>
                </div>
              </div>

              <div className="stats animate-slide-up">
                <div className="stat-card">
                  <div className="stat-icon" style={{ color: "var(--teal)", background: "var(--teal-light)" }}>
                    <FileText size={18} />
                  </div>
                  <div>
                    <strong>{documents.length}</strong>
                    <span>Documents in Vault</span>
                  </div>
                </div>

                <div className="stat-card">
                  <div className="stat-icon" style={{ color: "#c97a2b", background: "#fbede0" }}>
                    <AlertTriangle size={18} />
                  </div>
                  <div>
                    <strong>{deadlines.filter(d => !d.completed).length}</strong>
                    <span>Pending Obligations</span>
                  </div>
                </div>

                <div className="stat-card">
                  <div className="stat-icon" style={{ color: "#33455e", background: "#e8ecf1" }}>
                    <Sparkles size={18} />
                  </div>
                  <div>
                    <strong>{documents.filter((d) => d.status === "Ready").length}</strong>
                    <span>AI Indexed Summaries</span>
                  </div>
                </div>

                <div className="stat-card">
                  <div className="stat-icon" style={{ color: "#2f855a", background: "#e3f1e8" }}>
                    <ShieldCheck size={18} />
                  </div>
                  <div>
                    <strong>98.4%</strong>
                    <span>Compliance Health</span>
                  </div>
                </div>
              </div>

              <div className="columns animate-slide-up" style={{ animationDelay: "0.1s" }}>
                {/* Timeline Obligations */}
                <div className="panel">
                  <div className="panel-heading">
                    <b>Active Timelines & Tasks</b>
                    <button onClick={() => setScreen("deadlines")}>Open schedule</button>
                  </div>

                  <div className="timeline-dashboard-list">
                    {deadlines.slice(0, 3).map((deadline) => (
                      <div className={`deadline-row ${deadline.completed ? "completed-row" : ""}`} key={deadline.id}>
                        <span className={`severity ${deadline.severity}`} />
                        <div>
                          <b>{deadline.action}</b>
                          <small>{deadline.doc}</small>
                        </div>
                        {deadline.completed ? (
                          <span className="deadline-resolved-badge"><CheckCircle size={12} /> Resolved</span>
                        ) : (
                          <strong>
                            {deadline.due}
                            <small>{deadline.days} days left</small>
                          </strong>
                        )}
                      </div>
                    ))}
                  </div>
                </div>

                {/* AI Grounded Prompt Shortcut */}
                <div className="panel">
                  <div className="panel-heading">
                    <b>Ask AI Assistant</b>
                  </div>

                  <button className="ask-prompt" onClick={() => setScreen("ask")}>
                    <span><MessageSquareText size={18} /></span>
                    <div>
                      <b>&quot;When is my bursary renewal due?&quot;</b>
                      <small>Answers are grounded strictly in your verified S3 stored paperwork.</small>
                    </div>
                    <ChevronRight size={16} />
                  </button>

                  <div className="panel-heading" style={{ marginTop: 15 }}>
                    <b>Recently Indexed Documents</b>
                    <button onClick={() => setScreen("documents")}>Vault folders</button>
                  </div>

                  <div className="recent-docs-stack">
                    {documents.slice(0, 2).map((doc) => (
                      <button className="recent-doc-shortcut" key={doc.id} onClick={() => { setSelectedDoc(doc); setScreen("documents"); }}>
                        <div className="recent-doc-tab" style={{ background: typeStyles[doc.type].color }} />
                        <FileText size={16} style={{ color: "var(--slate)", marginLeft: 10, marginRight: 8 }} />
                        <span className="recent-doc-title">{doc.title}</span>
                        <ChevronRight size={14} className="muted" style={{ marginLeft: "auto" }} />
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </section>
          )}

          {/* SCREEN: DOCUMENTS */}
          {screen === "documents" && !selectedDoc && (
            <section className="screen">
              <div className="screen-heading split">
                <div>
                  <label>Document Vault</label>
                  <h1>POPIA Encrypted Files</h1>
                  <p>Every file is audited, classified, summarized and ready for grounded NLP retrieval.</p>
                </div>
                <button className="primary" onClick={() => setUploadOpen(true)}>
                  <UploadCloud size={16} style={{ marginRight: 6 }} /> Upload paperwork
                </button>
              </div>

              <div className="document-list-layout animate-slide-up">
                {documents.map((doc) => (
                  <div key={doc.id} className="document-card-row">
                    <div className="doc-accent" style={{ background: typeStyles[doc.type].color }} />
                    <div className="doc-content-main">
                      <div className="doc-meta-row">
                        <span className="tag" style={{ color: typeStyles[doc.type].color, background: typeStyles[doc.type].tint }}>
                          {typeStyles[doc.type].label}
                        </span>
                        <span className="confidence-label">
                          <CheckCircle size={10} style={{ color: "var(--success)" }} /> {doc.confidence}% Confidence
                        </span>
                      </div>
                      <h3>{doc.title}</h3>
                      <p className="doc-summary-preview">{doc.summary}</p>
                      <div className="doc-footer-meta">
                        <span><Clock size={11} /> {doc.date}</span>
                        <span><FileText size={11} /> {doc.pages} Page{doc.pages > 1 ? "s" : ""}</span>
                      </div>
                    </div>
                    <div className="doc-actions-col">
                      <button className="secondary" onClick={() => { setSelectedDoc(doc); setMobileDetailTab("extraction"); }}>
                        Inspect Extraction <ChevronRight size={14} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

          {/* SCREEN: DOCUMENT DETAIL (INSPECT EXTRACTION WITH LIVE BOUNDING BOX SYNC ON HOVER) */}
          {screen === "documents" && selectedDoc && (
            <section className="screen animate-fade-in">
              <button className="back" onClick={() => setSelectedDoc(null)}>
                ← Back to Vault Files
              </button>

              <div className="detail-heading">
                <i style={{ background: typeStyles[selectedDoc.type].color }} />
                <div>
                  <span className="tag" style={{ color: typeStyles[selectedDoc.type].color, background: typeStyles[selectedDoc.type].tint }}>
                    {typeStyles[selectedDoc.type].label}
                  </span>
                  <h1>{selectedDoc.title}</h1>
                  <p className="desktop-only">Uploaded & Parsed on {selectedDoc.date} · {selectedDoc.pages} Pages · Checked under strict South African compliance</p>
                  <p className="mobile-only">Parsed {selectedDoc.date} · {selectedDoc.pages} Pages</p>
                </div>
              </div>

              {/* Mobile-Only Dual Screen Segment Selector (Prevents crushed side-by-side) */}
              <div className="mobile-only-detail-tab-row">
                <button
                  className={mobileDetailTab === "extraction" ? "active" : ""}
                  onClick={() => setMobileDetailTab("extraction")}
                >
                  Extracted Data
                </button>
                <button
                  className={mobileDetailTab === "document" ? "active" : ""}
                  onClick={() => setMobileDetailTab("document")}
                >
                  Source Document
                </button>
              </div>

              <div className="columns mobile-split-layout">
                {/* Extraction Insights */}
                <div className={`panel flex-col ${mobileDetailTab !== "extraction" ? "mobile-hidden-panel" : ""}`}>
                  <div className="panel-tab-headers">
                    <button className="active-tab">✦ AI Extracted Details</button>
                    <span className="confidence-pill">{selectedDoc.confidence}% confidence</span>
                  </div>

                  <div className="detail-summary-box">
                    <strong>Document Summary:</strong>
                    <p>{selectedDoc.summary}</p>
                  </div>

                  <div className="panel-heading" style={{ marginTop: 15, marginBottom: 5 }}>
                    <b>Extracted Parameters</b>
                    <small className="desktop-only" style={{ color: "var(--slate)", display: "block" }}>Hover over cards to view source highlights in the document layout.</small>
                    <small className="mobile-only" style={{ color: "var(--slate)", display: "block" }}>Browse extracted ledger parameters.</small>
                  </div>

                  <div className="entity-cards-grid">
                    {selectedDoc.entities.map((entity) => (
                      <div
                        className={`entity-hover-card ${hoveredEntity === entity ? "card-highlighted" : ""}`}
                        key={entity.label}
                        onMouseEnter={() => setHoveredEntity(entity)}
                        onMouseLeave={() => setHoveredEntity(null)}
                      >
                        <small>{entity.label}</small>
                        <b>{entity.value}</b>
                      </div>
                    ))}
                  </div>

                  <button className="primary full" style={{ marginTop: 15 }} onClick={() => setScreen("ask")}>
                    <MessageSquareText size={15} style={{ marginRight: 6 }} /> Grounded Q&A Chat
                  </button>
                </div>

                {/* Simulated Document Layout Page */}
                <div className={`panel ${mobileDetailTab !== "document" ? "mobile-hidden-panel" : ""}`}>
                  <div className="panel-tab-headers">
                    <button className={docTab === "preview" ? "tab-btn active" : "tab-btn"} onClick={() => setDocTab("preview")}>Visual Preview</button>
                    <button className={docTab === "ocr" ? "tab-btn active" : "tab-btn"} onClick={() => setDocTab("ocr")}>Plain OCR Text</button>
                    <button className={docTab === "json" ? "tab-btn active" : "tab-btn"} onClick={() => setDocTab("json")}>JSON Schema</button>
                  </div>

                  {docTab === "preview" && (
                    <div className="interactive-document-container">
                      <div className="doc-page-canvas">
                        {/* Highlights layer */}
                        {selectedDoc.entities.map((entity) => (
                          entity.bbox && (
                            <div
                              key={entity.label}
                              className={`visual-bbox-highlight ${hoveredEntity === entity ? "active-bbox" : ""}`}
                              style={{
                                top: `${entity.bbox.top}%`,
                                left: `${entity.bbox.left}%`,
                                width: `${entity.bbox.width}%`,
                                height: `${entity.bbox.height}%`
                              }}
                              onMouseEnter={() => setHoveredEntity(entity)}
                              onMouseLeave={() => setHoveredEntity(null)}
                            >
                              <span className="tooltip-tag">{entity.label}</span>
                            </div>
                          )
                        ))}

                        {/* Visual representations of lines */}
                        <div className="simulated-letterhead">
                          <FolderOpen size={20} style={{ color: typeStyles[selectedDoc.type].color }} />
                          <b>REPUBLIC OF SOUTH AFRICA</b>
                        </div>
                        <div className="fake-title-line" style={{ width: "80%", height: "8px", background: "var(--line)", margin: "15px 0" }} />

                        <div className="fake-text-lines">
                          <div className="fake-line" style={{ width: "95%" }} />
                          <div className="fake-line" style={{ width: "90%" }} />
                          <div className="fake-line" style={{ width: "70%" }} />
                          <br />
                          {/* Bounding box visual clues */}
                          <div className="fake-line-bold" style={{ width: "85%" }}>[Extracted values glow on card hover]</div>
                          <div className="fake-line" style={{ width: "75%" }} />
                          <div className="fake-line" style={{ width: "92%" }} />
                          <br />
                          <div className="fake-line" style={{ width: "88%" }} />
                          <div className="fake-line" style={{ width: "90%" }} />
                          <div className="fake-line" style={{ width: "60%" }} />
                        </div>
                      </div>

                      <div className="preview-actions">
                        <button className="secondary"><Eye size={12} /> Full Screen</button>
                        <button className="secondary"><Download size={12} /> Download Original</button>
                      </div>
                    </div>
                  )}

                  {docTab === "ocr" && (
                    <div className="raw-ocr-viewport">
                      <pre>{selectedDoc.rawText || "No plaintext OCR was generated."}</pre>
                    </div>
                  )}

                  {docTab === "json" && (
                    <div className="json-schema-viewport">
                      <pre>
                        {JSON.stringify({
                          documentId: selectedDoc.id,
                          classification: selectedDoc.type,
                          extractionConfidence: selectedDoc.confidence / 100,
                          timestamp: "2026-07-26T14:55:00Z",
                          schemaVer: "1.2.0-ext",
                          extractedData: selectedDoc.entities.reduce((acc, ent) => {
                            acc[ent.label.replace(/\s+/g, "")] = ent.value;
                            return acc;
                          }, {} as Record<string, string>)
                        }, null, 2)}
                      </pre>
                    </div>
                  )}

                  <div className="po-compliance-box">
                    <LockKeyhole size={13} style={{ flexShrink: 0, marginTop: 1 }} />
                    <span><b>POPIA Restricted Session:</b> Access to original file blocks is logged to system audit tables under token auth scope.</span>
                  </div>
                </div>
              </div>
            </section>
          )}

          {/* SCREEN: ASK AI (GROUNDED CONVERSATIONAL CHAT) */}
          {screen === "ask" && (
            <section className="screen chat-screen animate-fade-in">
              <div className="screen-heading">
                <label>Grounded Assistant</label>
                <h1>Consult Your Vault Paperwork</h1>
                <p>Answers are computed using authorised context chunks only. No global model hallucination.</p>
              </div>

              <div className="chat">
                <div className="chat-log">
                  {chatMessages.map((msg, idx) => (
                    <div className={`message ${msg.role}`} key={idx}>
                      {msg.role === "assistant" && (
                        <span className="ai-avatar"><Sparkles size={13} /></span>
                      )}
                      <div>
                        <p>{msg.text}</p>
                        {msg.sources && msg.sources.length > 0 && (
                          <div className="chat-citations-wrapper">
                            <strong>Source Passages:</strong>
                            {msg.sources.map((src, sIdx) => (
                              <div className="citation-chip-badge" key={sIdx}>
                                <FileText size={10} style={{ marginRight: 4 }} />
                                <span>{src.doc} · {src.detail}</span>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  ))}
                  {aiTyping && (
                    <div className="message assistant">
                      <span className="ai-avatar"><Sparkles size={13} className="spin" /></span>
                      <div className="typing-indicator">
                        <span className="dot" />
                        <span className="dot" />
                        <span className="dot" />
                      </div>
                    </div>
                  )}
                </div>

                <div className="suggestions">
                  {["When is my bursary renewal?", "Do I still owe any fees?", "What are my NSFAS conditions?"].map((suggestion) => (
                    <button key={suggestion} onClick={() => handleSendChat(suggestion)}>
                      {suggestion}
                    </button>
                  ))}
                </div>

                <div className="chat-input">
                  <input
                    value={chatInput}
                    onChange={(e) => setInput(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && handleSendChat()}
                    placeholder="Ask details about funding amount, conditions or ledger fees..."
                  />
                  <button className="primary" onClick={() => handleSendChat()}>
                    <Send size={15} />
                  </button>
                </div>
              </div>
            </section>
          )}

          {/* SCREEN: DEADLINES */}
          {screen === "deadlines" && (
            <section className="screen animate-fade-in">
              <div className="screen-heading">
                <label>Timeline Schedule</label>
                <h1>Active Student Obligations</h1>
                <p>Obligations automatically parsed and timeline schedule updated dynamically from document extractions.</p>
              </div>

              <div className="timeline-layout">
                {deadlines.map((deadline, idx) => (
                  <div className={`timeline-item-block ${deadline.completed ? "timeline-item-done" : ""}`} key={deadline.id}>
                    <div className={`timeline-indicator ${deadline.severity}`} />
                    {idx < deadlines.length - 1 && <div className="timeline-connecting-line" />}

                    <div className="timeline-card">
                      <div className="timeline-card-header">
                        <span className="date-badge">{deadline.due}</span>
                        {deadline.completed ? (
                          <span className="resolved-status-label"><CheckSquare size={13} /> Completed</span>
                        ) : (
                          <span className={`urgency-pill ${deadline.severity}`}>{deadline.days} Days Remaining</span>
                        )}
                      </div>
                      <h3>{deadline.action}</h3>
                      <span className="deadline-associated-file">
                        <FileText size={12} /> {deadline.doc}
                      </span>

                      {!deadline.completed && (
                        <div className="timeline-actions">
                          <button
                            className="secondary action-btn"
                            onClick={() => handleResolveDeadline(deadline.id)}
                            disabled={completingDeadlineId !== null}
                          >
                            {completingDeadlineId === deadline.id ? (
                              <>
                                <RotateCw size={12} className="spin" style={{ marginRight: 6 }} />
                                Verifying Submission...
                              </>
                            ) : (
                              "Upload & Resolve Task"
                            )}
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

          {/* SCREEN: SECURITY & AUDIT (POPIA FOCUS) */}
          {screen === "security" && (
            <section className="screen animate-fade-in">
              <div className="screen-heading">
                <label>Compliance Hub</label>
                <h1>POPIA Compliance & Encryption Control</h1>
                <p>Folio enforces strict privacy compliance in accordance with South Africa&apos;s POPIA regulations.</p>
              </div>

              <div className="columns" style={{ gridTemplateColumns: "1fr 1.2fr" }}>
                {/* Security and Governance Controls */}
                <div className="panel">
                  <div className="panel-heading">
                    <b>Data Governance Controls</b>
                  </div>

                  <div className="security-settings-stack">
                    <div className="setting-control-row">
                      <div>
                        <b>Multi-factor Auth (MFA)</b>
                        <small>Strict OTP checks during Single Sign-On registration.</small>
                      </div>
                      <button className="toggle on"><span /></button>
                    </div>

                    <div className="setting-control-row">
                      <div>
                        <b>App Biometric Locker</b>
                        <small>Verify session token when opening native workspace.</small>
                      </div>
                      <button className="toggle on"><span /></button>
                    </div>

                    <div className="setting-control-row">
                      <div>
                        <b>Financial Aid Data Share</b>
                        <small>Grant temporary summary review access to student advisor.</small>
                      </div>
                      <button className={`toggle ${sharing ? "on" : ""}`} onClick={() => setSharing(!sharing)}>
                        <span />
                      </button>
                    </div>
                  </div>

                  <div className="security-notice-box-gold">
                    <LockKeyhole size={14} style={{ flexShrink: 0, marginTop: 1 }} />
                    <div>
                      <b>AES-256 KMS At-Rest Encryption</b>
                      <p>Stored document objects reside in encrypted S3 volumes. Access is authorized via signed URL parameters with brief session durations.</p>
                    </div>
                  </div>
                </div>

                {/* Live Audit Log Ledger */}
                <div className="panel flex-col">
                  <div className="panel-heading" style={{ marginBottom: 5 }}>
                    <b>Immutable POPIA Access Ledger</b>
                    <button className="export-logs-action" onClick={handleExportLogs}>
                      <FileJson size={12} style={{ marginRight: 4 }} /> Export Audit JSON
                    </button>
                  </div>

                  {/* Audit search and category filters */}
                  <div className="audit-controls-row">
                    <div className="audit-search-field">
                      <Search size={12} />
                      <input
                        placeholder="Search logs..."
                        value={logSearch}
                        onChange={(e) => setLogSearch(e.target.value)}
                      />
                    </div>
                    <select
                      value={logFilter}
                      onChange={(e) => setLogFilter(e.target.value as LogCategory)}
                      className="audit-category-select"
                    >
                      <option value="All">All Categories</option>
                      <option value="Access">Access Logs</option>
                      <option value="Document">Files Activity</option>
                      <option value="Security">Security Logs</option>
                      <option value="AI Queries">AI Grounded Chat</option>
                    </select>
                  </div>

                  <div className="audit-ledger-stack">
                    {filteredAuditLogs.length > 0 ? (
                      filteredAuditLogs.map((entry) => (
                        <div className="audit-entry-card" key={entry.id}>
                          <div className="audit-card-top">
                            <span className="audit-timestamp">{entry.time}</span>
                            <span className={`audit-badge-pill ${entry.category}`}>{entry.category}</span>
                          </div>
                          <p>
                            <b>{entry.actor}</b> — {entry.action}
                          </p>
                          <small>{entry.detail}</small>
                        </div>
                      ))
                    ) : (
                      <div className="empty-audit-logs">
                        <span>No log activities match the search parameter.</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </section>
          )}
        </div>

        {/* Mobile bottom navigation bar */}
        <div className="mobile-bottom-navigation-bar">
          {navItems.map(([key, label, Icon]) => (
            <button
              key={key}
              className={screen === key || (screen === "documents" && selectedDoc && key === "documents") ? "active" : ""}
              onClick={() => {
                setScreen(key);
                setSelectedDoc(null);
              }}
            >
              <Icon size={18} />
              <span>{label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* MODAL: SECURE PAPERWORK UPLOAD FLOW */}
      {uploadOpen && (
        <div className="modal-backdrop animate-fade-in" onClick={() => setUploadOpen(false)}>
          <div className="modal animate-slide-up" onClick={(e) => e.stopPropagation()}>
            <div className="modal-heading">
              <b>Secure Document Dispatch</b>
              <button className="close-modal-btn" onClick={() => setUploadOpen(false)}>
                <X size={17} />
              </button>
            </div>

            {uploadStep === "idle" ? (
              <div className="upload-interactive-form">
                <div className="dropzone">
                  <UploadCloud size={32} style={{ color: "var(--teal)" }} />
                  <b>Drag original PDF letter here</b>
                  <small>Max file size limit is 20MB. Fully encrypted.</small>
                </div>

                <label className="modal-input-label">
                  Document Title / Reference Name
                  <input
                    value={uploadTitle}
                    onChange={(e) => setUploadTitle(e.target.value)}
                    placeholder="e.g. NSFAS 2026 Appeal Acceptance"
                    className="modal-text-input"
                  />
                </label>

                <label className="modal-input-label">
                  Taxonomy Category
                  <select
                    value={uploadType}
                    onChange={(e) => setUploadType(e.target.value as DocType)}
                    className="modal-select-input"
                  >
                    {Object.keys(typeStyles).map((t) => (
                      <option key={t} value={t}>{t}</option>
                    ))}
                  </select>
                </label>

                <button className="primary full" onClick={handleUploadSubmit} style={{ marginTop: 10 }}>
                  Upload securely <UserCheck size={14} style={{ marginLeft: 6 }} />
                </button>
              </div>
            ) : (
              <div className="processing-state-viewport">
                <div className="progress-spinner-container">
                  <RotateCw className="spin" size={32} style={{ color: "var(--teal)" }} />
                </div>
                <h3>
                  {uploadStep === "uploading" && "Uploading to Secure S3 Vault..."}
                  {uploadStep === "ocr" && "Extracting OCR plaintext..."}
                  {uploadStep === "nlp" && "Classifying entities & NLP metrics..."}
                </h3>
                <p>Documents are isolated and processed in secure cloud sandboxes.</p>

                <div className="upload-progress-bar-container">
                  <div className="upload-progress-fill" style={{ width: `${uploadProgress}%` }} />
                </div>
                <span className="upload-progress-percentage">{uploadProgress}% Complete</span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* TOAST SYSTEM */}
      {toast && (
        <div className="toast animate-slide-up-toast">
          <CheckCircle size={14} style={{ color: "#fff" }} />
          <span>{toast}</span>
        </div>
      )}
    </main>
  );
}
