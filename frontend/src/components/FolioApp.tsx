"use client";

import { useMemo, useState, useEffect, useRef } from "react";
import { createClient } from "@supabase/supabase-js";
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
  CheckSquare,
  Mic,
  MicOff,
  CalendarDays,
  Trash2,
  ArchiveRestore,
  ScanFace,
  ChevronLeft,
  ChevronDown,
  Info
} from "lucide-react";

type DocType = "Document" | "Funding Award Letter" | "Bursary Agreement" | "Fee Statement" | "Bank Letter" | "Appeal Correspondence";

type DocEntity = {
  label: string;
  value: string;
  bbox?: { top: number; left: number; width: number; height: number }; // Simulated document bounding box for mapping hover effects
};

type Document = {
  id: number | string;
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

type AuthUser = { id: string; email: string; displayName: string };
type Deadline = { id: number; action: string; doc: string; due: string; days: number; severity: string; completed: boolean };
type ChatMessage = {
  role: "assistant" | "user";
  text: string;
  sourceDoc?: string;
  sourcePage?: number;
  sources?: { doc: string; detail: string }[];
  complianceConfidence?: number;
  complianceLogic?: string;
};
const API_URL = (process.env.NEXT_PUBLIC_API_URL || "/api").replace(/\/$/, "");

const typeStyles: Record<DocType, { label: string; color: string; tint: string; border: string }> = {
  "Document": { label: "Document", color: "#33455e", tint: "#eef1f5", border: "#d8dee7" },
  "Funding Award Letter": { label: "Funding", color: "#c97a2b", tint: "#fbede0", border: "#f3dbca" },
  "Bursary Agreement": { label: "Bursary", color: "#0e7c74", tint: "#e4f2f0", border: "#cbe3e0" },
  "Fee Statement": { label: "Fees", color: "#33455e", tint: "#e8ecf1", border: "#ced5de" },
  "Bank Letter": { label: "Bank", color: "#6e5a7e", tint: "#eee8f2", border: "#dbdae8" },
  "Appeal Correspondence": { label: "Appeal", color: "#b3432d", tint: "#fbe7e2", border: "#f3cfc6" },
};

const initialDeadlines: Deadline[] = [];

const initialAuditLogs: AuditEntry[] = [];

const navItems = [
  ["dashboard", "Dashboard", LayoutDashboard],
  ["documents", "Documents", FileText],
  ["ask", "Ask AI", MessageSquareText],
  ["security", "Security", ShieldCheck],
] as const;

export default function FolioApp() {
  // Authentication & MFA flow states
  const [authStep, setAuthStep] = useState<"checking" | "credentials" | "mfa" | "authenticated">("checking");
  const [authMode, setAuthMode] = useState<"login" | "register">("login");
  const [displayNameInput, setDisplayNameInput] = useState("");
  const [emailInput, setEmailInput] = useState("");
  const [passwordInput, setPasswordInput] = useState("");
  const [authUser, setAuthUser] = useState<AuthUser | null>(null);
  const [challengeId, setChallengeId] = useState("");
  const [authLoading, setAuthLoading] = useState(false);
  const [authError, setAuthError] = useState("");
  const [mfaDigits, setMfaDigits] = useState<string[]>(["", "", "", "", "", ""]);
  const [mfaError, setMfaError] = useState("");
  const [mfaTimer, setMfaTimer] = useState(59);
  const [isResending, setIsResending] = useState(false);
  const mfaRefs = useRef<(HTMLInputElement | null)[]>([]);
  const chatLogRef = useRef<HTMLDivElement | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const recognitionRef = useRef<{ stop: () => void } | null>(null);

  // Navigation, documents, and interactive highlights
  const [screen, setScreen] = useState<Screen>("dashboard");
  const [documents, setDocuments] = useState<Document[]>([]);
  const [selectedDoc, setSelectedDoc] = useState<Document | null>(null);
  const [hoveredEntity, setHoveredEntity] = useState<DocEntity | null>(null);
  const [docTab, setDocTab] = useState<"preview" | "ocr" | "json">("preview");

  // Mobile layout states
  const [mobileDetailTab, setMobileDetailTab] = useState<"extraction" | "document">("extraction");
  const [mobileProfileOpen, setMobileProfileOpen] = useState(false);

  // Upload state machine
  const [uploadOpen, setUploadOpen] = useState(false);
  const [uploadTitle, setUploadTitle] = useState("");
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

  // Voice command states
  const [voiceActive, setVoiceActive] = useState(false);
  const [voiceSearchActive, setVoiceSearchActive] = useState(false);
  const [voiceStatus, setVoiceStatus] = useState<"listening" | "transcribing" | null>(null);

  // NL Search overlay states
  const [searchQuery, setSearchQuery] = useState("");
  const [searchOpen, setSearchOpen] = useState(false);
  const [mobileSearchOpen, setMobileSearchOpen] = useState(false);
  const [searchResults, setSearchResults] = useState<{ type: "doc" | "deadline" | "ai"; title: string; detail: string; action?: () => void }[]>([]);

  // Calendar view state for Deadlines screen
  const [deadlineView, setDeadlineView] = useState<"timeline" | "calendar">("timeline");
  const [calendarMonth, setCalendarMonth] = useState(new Date(2026, 1, 1)); // Feb 2026

  // Deleted documents (soft-delete + recovery)
  const [deletedDocs, setDeletedDocs] = useState<Document[]>([]);
  const [showRecycleBin, setShowRecycleBin] = useState(false);

  // Biometric state
  const [biometricScanning, setBiometricScanning] = useState(false);
  const [biometricDone, setBiometricDone] = useState(false);

  // Notification bell
  const [notifOpen, setNotifOpen] = useState(false);

  // Security toggle states
  const [mfaEnabled, setMfaEnabled] = useState(true);
  const [biometricEnabled, setBiometricEnabled] = useState(true);

  // Real file upload
  const [uploadFileName, setUploadFileName] = useState("");
  const [uploadFile, setUploadFile] = useState<File | null>(null);

  // Grounded Chat Q&A states
  const [chatInput, setInput] = useState("");
  const [chatMessages, setMessages] = useState<ChatMessage[]>([
    {
      role: "assistant",
      text: "Hi — ask me to explain, compare, summarise, draft, or reason through anything in your documents. I’ll show the sources I used and say when the evidence is uncertain.",
    },
  ]);
  const [aiTyping, setAiTyping] = useState(false);

  // Toasts (supports multiple stacked toasts)
  const [toast, setToast] = useState("");
  const [toastType, setToastType] = useState<"info" | "success" | "error">("success");

  // Auto clear toast
  useEffect(() => {
    if (toast) {
      const t = setTimeout(() => setToast(""), 4000);
      return () => clearTimeout(t);
    }
  }, [toast]);

  // Auto-scroll chat log on new messages
  useEffect(() => {
    if (chatLogRef.current) {
      chatLogRef.current.scrollTop = chatLogRef.current.scrollHeight;
    }
  }, [chatMessages, aiTyping]);

  useEffect(() => () => recognitionRef.current?.stop(), []);

  useEffect(() => {
    fetch(`${API_URL}/v1/auth/me`, { credentials: "include" })
      .then(async (response) => response.ok ? response.json() : Promise.reject())
      .then((user: AuthUser) => { setAuthUser(user); setAuthStep("authenticated"); })
      .catch(() => setAuthStep("credentials"));
  }, []);

  useEffect(() => {
    if (authStep !== "authenticated") return;
    fetch(`${API_URL}/v1/documents`, { credentials: "include" })
      .then(async response => {
        const data = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(data.message || "Unable to load your documents");
        return data.documents as Document[];
      })
      .then(setDocuments)
      .catch(error => { setToast(error instanceof Error ? error.message : "Unable to load your documents"); setToastType("error"); });
  }, [authStep]);

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

  const handleCredentialsSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setAuthLoading(true); setAuthError("");
    try {
      const payload = authMode === "register"
        ? { displayName: displayNameInput, email: emailInput, password: passwordInput }
        : { email: emailInput, password: passwordInput };
      const response = await fetch(`${API_URL}/v1/auth/${authMode}`, {
        method: "POST", credentials: "include", headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" }, body: JSON.stringify(payload)
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data.message || "Unable to continue");
      setChallengeId(data.challengeId); setAuthStep("mfa"); setMfaTimer(data.resendAfterSeconds || 60);
      setMfaError(""); setMfaDigits(["", "", "", "", "", ""]);
      setToast(`Verification code sent to ${data.destination}.`);
    } catch (error) { setAuthError(error instanceof Error ? error.message : "Unable to continue"); }
    finally { setAuthLoading(false); }
  };

  const handleMfaChange = (index: number, val: string) => {
    // Browsers commonly provide the whole OTP when the user pastes it or
    // when autocomplete="one-time-code" fills the field. The old handler
    // rejected that value, making an otherwise valid login appear broken.
    const digits = val.replace(/\D/g, "");
    if (!digits) {
      const nextMfa = [...mfaDigits];
      nextMfa[index] = "";
      setMfaDigits(nextMfa);
      return;
    }
    const nextMfa = [...mfaDigits];
    digits.slice(0, 6 - index).split("").forEach((digit, offset) => {
      nextMfa[index + offset] = digit;
    });
    setMfaDigits(nextMfa);

    // Auto-focus next input
    const nextIndex = Math.min(index + digits.length, 5);
    if (nextIndex < 5) {
      mfaRefs.current[nextIndex]?.focus();
    }
    // Auto-submit when last digit entered
    if (nextMfa.join("").length === 6) {
      const code = nextMfa.join("");
      if (code.length === 6) {
        setTimeout(() => handleVerifyMfa(nextMfa), 150);
      }
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

  const handleVerifyMfa = async (digits?: string[]) => {
    const code = (digits ?? mfaDigits).join("");
    if (code.length < 6) {
      setMfaError("Please fill out the full 6-digit verification security code.");
      return;
    }
    setAuthLoading(true); setMfaError("");
    try {
      const response = await fetch(`${API_URL}/v1/auth/verify`, {
        method: "POST", credentials: "include", headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" },
        body: JSON.stringify({ challengeId, code })
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data.message || "Unable to verify this code");
      setAuthUser(data); setAuthStep("authenticated"); setPasswordInput("");
      setToast(authMode === "register" ? "Account verified. Welcome to Folio." : "Identity verified. Welcome back.");
      // Log Secure Session Initiation
      const newLog: AuditEntry = {
        id: Date.now(),
        time: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }) + ", " + new Date().toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" }),
        actor: "Student",
        action: "Secure Session Started",
        detail: "Email MFA verified and an encrypted Folio session was created.",
        category: "Security"
      };
      setAuditLogs((prev) => [newLog, ...prev]);
    } catch (error) { setMfaError(error instanceof Error ? error.message : "Unable to verify this code"); }
    finally { setAuthLoading(false); }
  };

  const handleResendMfa = async () => {
    setIsResending(true);
    try {
      const response = await fetch(`${API_URL}/v1/auth/resend`, { method: "POST", credentials: "include",
        headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" }, body: JSON.stringify({ challengeId }) });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data.message || "Unable to resend the code");
      setChallengeId(data.challengeId); setMfaTimer(data.resendAfterSeconds || 60);
      setMfaDigits(["", "", "", "", "", ""]);
      setMfaError(""); setToast(`A fresh code was sent to ${data.destination}.`);
    } catch (error) { setMfaError(error instanceof Error ? error.message : "Unable to resend the code"); }
    finally { setIsResending(false); }
  };

  const handleLogout = async () => {
    await fetch(`${API_URL}/v1/auth/logout`, { method: "POST", credentials: "include", headers: { "X-Requested-With": "FolioWeb" } }).catch(() => undefined);
    setAuthUser(null); setAuthStep("credentials"); setPasswordInput(""); setMobileProfileOpen(false);
  };

  // Direct-to-Supabase private storage upload followed by server-side extraction and summarisation.
  const handleUploadSubmit = async () => {
    if (!uploadTitle.trim() || !uploadFile) {
      setToast(!uploadFile ? "Choose a document to upload." : "Please state a clear document title.");
      setToastType("error"); return;
    }
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
    if (!supabaseUrl || !publishableKey) { setToast("Supabase is not configured yet."); setToastType("error"); return; }
    setUploadStep("uploading"); setUploadProgress(10);
    try {
      const prepare = await fetch(`${API_URL}/v1/documents/upload-url`, {
        method: "POST", credentials: "include", headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" },
        body: JSON.stringify({ title: uploadTitle, fileName: uploadFile.name, mimeType: uploadFile.type, byteSize: uploadFile.size }),
      });
      const upload = await prepare.json().catch(() => ({}));
      if (!prepare.ok) throw new Error(upload.message || "Unable to prepare secure upload");
      setUploadProgress(35);
      const client = createClient(supabaseUrl, publishableKey, { auth: { persistSession: false } });
      const { error: storageError } = await client.storage.from("folio-documents")
        .uploadToSignedUrl(upload.path, upload.token, uploadFile, { contentType: uploadFile.type, upsert: false });
      if (storageError) throw new Error(storageError.message);
      setUploadProgress(85);
      const complete = await fetch(`${API_URL}/v1/documents/complete`, {
        method: "POST", credentials: "include", headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" },
        body: JSON.stringify({ documentId: upload.documentId }),
      });
      const completed = await complete.json().catch(() => ({}));
      if (!complete.ok) throw new Error(completed.message || "Unable to confirm secure upload");
      setUploadStep("ocr"); setUploadProgress(92);
      const processedResponse = await fetch(`${API_URL}/v1/documents/process`, {
        method: "POST", credentials: "include", headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" },
        body: JSON.stringify({ documentId: upload.documentId }),
      });
      const processed = await processedResponse.json().catch(() => ({}));
      if (!processedResponse.ok) throw new Error(processed.message || "The document was stored but could not be processed");
      setUploadStep(processed.status === "READY" ? "done" : "nlp"); setUploadProgress(100);
      const refresh = await fetch(`${API_URL}/v1/documents`, { credentials: "include" });
      const refreshed = await refresh.json();
      if (refresh.ok) setDocuments(refreshed.documents);
      setUploadStep("idle"); setUploadOpen(false); setUploadTitle(""); setUploadFileName(""); setUploadFile(null);
      if (fileInputRef.current) fileInputRef.current.value = "";
      setToast(processed.status === "READY" ? "Document uploaded, extracted, and summarised." : "Document uploaded securely and needs manual review."); setToastType("success");
    } catch (error) {
      setUploadStep("idle"); setUploadProgress(0); setToast(error instanceof Error ? error.message : "Upload failed"); setToastType("error");
    }
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
        detail: `Verification complete: Student fulfilled action '${targetDeadline?.action}' associated with '${targetDeadline?.doc}'.`,
        category: "Security"
      };
      setAuditLogs((prev) => [newLog, ...prev]);
    }, 1500);
  };

  // AI QA Grounded responses log
  const handleSendChat = async (question = chatInput) => {
    if (!question.trim() || aiTyping) return;
    const requestHistory = chatMessages.slice(-10).map(({ role, text }) => ({ role, text }));
    setMessages((prev) => [...prev, { role: "user", text: question.trim() }, { role: "assistant", text: "" }]);
    setInput("");
    setAiTyping(true);

    try {
      const response = await fetch(`${API_URL}/v1/ai/ask`, { method: "POST", credentials: "include",
        headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" }, body: JSON.stringify({ question, history: requestHistory }) });
      if (!response.ok || !response.body) {
        const data = await response.json().catch(() => ({}));
        throw new Error(data.message || "The assistant could not answer right now");
      }
      const reader = response.body.getReader(), decoder = new TextDecoder();
      let pending = "", responseText = "", matchedDoc: string | undefined, matchedPage: number | undefined;
      while (true) {
        const { done, value } = await reader.read();
        pending += decoder.decode(value || new Uint8Array(), { stream: !done });
        const lines = pending.split("\n");
        pending = lines.pop() || "";
        for (const line of lines) {
          if (!line.trim()) continue;
          const event = JSON.parse(line) as { type: "delta" | "replace" | "done"; text?: string; citations?: Array<{ title: string; page: number }>; compliance?: { confidence: number; logic: string } | null };
          if (event.type === "delta" && event.text) {
            responseText += event.text;
            setAiTyping(false);
            setMessages((prev) => prev.map((message, index) => index === prev.length - 1 ? { ...message, text: message.text + event.text } : message));
          } else if (event.type === "replace") {
            responseText = event.text || "I could not complete that answer.";
            setMessages((prev) => prev.map((message, index) => index === prev.length - 1 ? { ...message, text: responseText } : message));
          } else if (event.type === "done") {
            const citations = (event.citations || []).map((citation) => ({ doc: citation.title, detail: `Page ${citation.page}` }));
            matchedDoc = citations[0]?.doc;
            matchedPage = event.citations?.[0]?.page;
            setMessages((prev) => prev.map((message, index) => index === prev.length - 1 ? { ...message, sourceDoc: matchedDoc, sourcePage: matchedPage, sources: citations,
              complianceConfidence: event.compliance?.confidence, complianceLogic: event.compliance?.logic } : message));
          }
        }
        if (done) break;
      }
      // Read response aloud if voice was active
      if (voiceActive) speakText(responseText);

      // Log AI Query event
      const newLog: AuditEntry = {
        id: Date.now(),
        time: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }) + ", " + new Date().toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" }),
        actor: "Student",
        action: "AI Grounded Query",
        detail: `Asked a document-grounded question. ${matchedDoc ? `Evidence: ${matchedDoc}` : "The assistant abstained outside available evidence."}`,
        category: "AI Queries"
      };
      setAuditLogs((prev) => [newLog, ...prev]);
    } catch (error) {
      const message = error instanceof Error ? error.message : "The assistant could not answer right now";
      setMessages((prev) => prev.map((item, index) => index === prev.length - 1 && item.role === "assistant" ? { ...item, text: message } : item));
      setToast(message); setToastType("error");
    } finally { setAiTyping(false); }
  };

  // Download document OCR text as a .txt file
  const handleDownloadOCR = (doc: Document) => {
    const blob = new Blob([doc.rawText || doc.summary], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${doc.title.replace(/[^a-z0-9]/gi, "_")}_ocr.txt`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
    setToast("OCR text downloaded.");
  };

  // Open OCR text in a new browser tab (full screen)
  const handleFullScreen = (doc: Document) => {
    const html = `<!DOCTYPE html><html><head><title>${doc.title}</title><style>body{font-family:monospace;white-space:pre-wrap;padding:32px;background:#faf9f5;color:#0b132b;font-size:14px;line-height:1.7;max-width:860px;margin:auto}</style></head><body>${doc.rawText || doc.summary}</body></html>`;
    const blob = new Blob([html], { type: "text/html" });
    const url = URL.createObjectURL(blob);
    window.open(url, "_blank");
  };

  // Navigate to a source document from a chat citation
  const handleCitationClick = (docTitle: string) => {
    const match = documents.find((d) => d.title === docTitle);
    if (match) {
      setSelectedDoc(match);
      setScreen("documents");
      setToast(`Opened: ${match.title}`);
      // Log access
      const newLog: AuditEntry = {
        id: Date.now(),
        time: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }) + ", " + new Date().toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" }),
        actor: "Student",
        action: "Document Viewed",
        detail: `${match.title} accessed via AI citation link (POPIA Audited Access)`,
        category: "Access"
      };
      setAuditLogs((prev) => [newLog, ...prev]);
    }
  };

  // NL intent-based search handler
  const handleNLSearch = (query: string) => {
    setSearchQuery(query);
    if (!query.trim()) { setSearchResults([]); return; }
    const q = query.toLowerCase();
    const results: typeof searchResults = [];
    const closeIntentSearch = () => { setSearchOpen(false); setMobileSearchOpen(false); setSearchQuery(""); };
    const addDocByType = (type: DocType) => {
      const doc = documents.find((item) => item.type === type);
      if (doc) results.push({ type: "doc", title: doc.title, detail: `${doc.type} · ${doc.date}`, action: () => { setSelectedDoc(doc); setScreen("documents"); closeIntentSearch(); } });
    };
    const addDeadlineByType = (type: DocType) => {
      const doc = documents.find((item) => item.type === type);
      const deadline = doc && deadlines.find((item) => item.doc === doc.title);
      if (deadline) results.push({ type: "deadline", title: deadline.action, detail: `Due: ${deadline.due} · from ${deadline.doc}`, action: () => { setScreen("deadlines"); closeIntentSearch(); } });
    };
    const has = (...terms: string[]) => terms.some((term) => q.includes(term));
    let intentMatched = false;
    if (has("interview", "apply", "application", "engineer", "graduate", "job", "career")) {
      intentMatched = true; addDocByType("Funding Award Letter"); addDocByType("Bursary Agreement"); addDocByType("Fee Statement");
      results.push({ type: "ai", title: "Open graduate-application summary", detail: "Grounded in your funding, bursary, and fee documents.", action: () => { setInput("Draft a summary of my job application documents"); setScreen("ask"); closeIntentSearch(); } });
    }
    if (has("funding", "award", "condition", "average", "allowance", "proof", "registration")) { intentMatched = true; addDocByType("Funding Award Letter"); addDeadlineByType("Funding Award Letter"); }
    if (has("bursary", "renew", "transcript", "declaration")) { intentMatched = true; addDocByType("Bursary Agreement"); addDeadlineByType("Bursary Agreement"); }
    if (has("fee", "fees", "payment", "pay", "balance", "owe", "statement")) { intentMatched = true; addDocByType("Fee Statement"); addDeadlineByType("Fee Statement"); }
    if (has("bank", "disbursement", "account", "confirmation")) { intentMatched = true; addDocByType("Bank Letter"); }
    if (intentMatched) {
      if (!results.some((result) => result.type === "ai")) results.push({ type: "ai", title: "Ask AI for a grounded summary", detail: "Open an answer with document citations.", action: () => { setInput(query); setScreen("ask"); closeIntentSearch(); } });
      setSearchResults(results);
      return;
    }

    documents.forEach((doc) => {
      if (
        doc.title.toLowerCase().includes(q) ||
        doc.summary.toLowerCase().includes(q) ||
        doc.type.toLowerCase().includes(q) ||
        doc.entities.some((e) => e.value.toLowerCase().includes(q) || e.label.toLowerCase().includes(q))
      ) {
        results.push({ type: "doc", title: doc.title, detail: `${doc.type} · ${doc.date}`, action: () => { setSelectedDoc(doc); setScreen("documents"); setSearchOpen(false); setSearchQuery(""); } });
      }
    });

    deadlines.forEach((d) => {
      if (d.action.toLowerCase().includes(q) || d.doc.toLowerCase().includes(q)) {
        results.push({ type: "deadline", title: d.action, detail: `Due: ${d.due} · from ${d.doc}`, action: () => { setScreen("deadlines"); setSearchOpen(false); setSearchQuery(""); } });
      }
    });

    if (q.includes("interview") || q.includes("apply") || q.includes("engineer") || q.includes("graduate") || q.includes("job")) {
      results.push({ type: "ai", title: "Ask AI about career documents", detail: "Folio will search your vault for relevant files and draft a summary.", action: () => { setInput(`draft a summary of what I need to know for my interview according to my files`); setScreen("ask"); setSearchOpen(false); setSearchQuery(""); } });
    }

    if (q.includes("bursary") || q.includes("renew") || q.includes("funding") || q.includes("award") || q.includes("fee") || q.includes("pay")) {
      results.push({ type: "ai", title: "Ask AI about this topic", detail: `Query your documents: "${query}"`, action: () => { setInput(query); setScreen("ask"); setSearchOpen(false); setSearchQuery(""); } });
    }

    setSearchResults(results);
  };

  // Voice command handler — uses real Web Speech API, falls back to simulation
  const setVoiceSurface = (target: "chat" | "search" | null, status: "listening" | "transcribing" | null = null) => {
    setVoiceActive(target === "chat");
    setVoiceSearchActive(target === "search");
    setVoiceStatus(status);
  };

  const stopVoiceInput = () => {
    const activeRecognition = recognitionRef.current;
    recognitionRef.current = null;
    setVoiceSurface(null);
    activeRecognition?.stop();
  };

  const handleVoiceInput = (target: "chat" | "search") => {
    if (recognitionRef.current) {
      stopVoiceInput();
      return;
    }

    const isChat = target === "chat";

    type SpeechRecognitionCtor = new () => {
      lang: string;
      interimResults: boolean;
      maxAlternatives: number;
      start: () => void;
      stop: () => void;
      onresult: ((e: { results: { [k: number]: { [k: number]: { transcript: string }; isFinal?: boolean }; length: number } }) => void) | null;
      onerror: (() => void) | null;
      onend: (() => void) | null;
    };

    const SpeechRecognitionAPI: SpeechRecognitionCtor | null =
      (typeof window !== "undefined" &&
        ((window as unknown as { SpeechRecognition?: SpeechRecognitionCtor }).SpeechRecognition ||
         (window as unknown as { webkitSpeechRecognition?: SpeechRecognitionCtor }).webkitSpeechRecognition)) || null;

    if (SpeechRecognitionAPI) {
      const recognition = new SpeechRecognitionAPI();
      recognition.lang = "en-ZA";
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;
      recognitionRef.current = recognition;

      setVoiceSurface(target, "listening");
      setToast("Listening... speak your question now.");

      recognition.onresult = (event) => {
        const phrase = Array.from({ length: event.results.length }, (_, index) => event.results[index][0].transcript).join("").trim();
        const isFinal = Array.from({ length: event.results.length }, (_, index) => event.results[index].isFinal).every(Boolean);
        if (isChat) {
          setInput(phrase);
        } else {
          handleNLSearch(phrase);
          setSearchOpen(true);
        }
        setVoiceStatus(isFinal ? "transcribing" : "listening");
      };

      recognition.onerror = () => {
        if (recognitionRef.current !== recognition) return;
        recognitionRef.current = null;
        setVoiceSurface(null);
        const fallback = "What are my funding award conditions?";
        if (isChat) {
          setInput(fallback);
        } else {
          setSearchQuery("");
          setSearchResults([]);
          setSearchOpen(true);
          setMobileSearchOpen(true);
        }
        setToast(isChat ? "Voice is unavailable. An editable example is ready; you can type instead." : "Voice is unavailable. Type your search instead.");
      };

      recognition.onend = () => {
        if (recognitionRef.current !== recognition) return;
        recognitionRef.current = null;
        setVoiceSurface(null);
        setToast(isChat ? "Voice transcription is ready to edit or send." : "Voice search transcription is ready to refine.");
      };

      recognition.start();
    } else {
      const fallback = "What are my funding award conditions?";
      if (isChat) {
        setInput(fallback);
      } else {
        setSearchQuery("");
        setSearchResults([]);
        setSearchOpen(true);
        setMobileSearchOpen(true);
      }
      setToast(isChat ? "Voice input is not supported here. An editable example is ready; you can type instead." : "Voice input is not supported here. Type your search instead.");
    }
  };

  // Read AI response aloud via speechSynthesis
  const speakText = (text: string) => {
    if (typeof window === "undefined" || !window.speechSynthesis) return;
    window.speechSynthesis.cancel();
    const utter = new SpeechSynthesisUtterance(text);
    utter.lang = "en-ZA";
    utter.rate = 0.95;
    window.speechSynthesis.speak(utter);
  };

  // Soft-delete a document (move to recycle bin)
  const handleDeleteDocument = async (doc: Document) => {
    const response = await fetch(`${API_URL}/v1/documents/${doc.id}`, {
      method: "DELETE", credentials: "include", headers: { "X-Requested-With": "FolioWeb" },
    }).catch(() => null);
    if (!response?.ok) {
      setToast("That document could not be moved to the recycle bin.");
      setToastType("error");
      return;
    }
    setDocuments((prev) => prev.filter((d) => d.id !== doc.id));
    setDeletedDocs((prev) => [doc, ...prev]);
    setSelectedDoc(null);
    setToast(`'${doc.title}' moved to recycle bin. You can restore it anytime.`);
    setToastType("success");
    const newLog: AuditEntry = {
      id: Date.now(),
      time: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }) + ", " + new Date().toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" }),
      actor: "Student",
      action: "Document Deleted",
      detail: `'${doc.title}' soft-deleted and moved to recovery bin (restorable).`,
      category: "Document"
    };
    setAuditLogs((prev) => [newLog, ...prev]);
  };

  // Restore a document from recycle bin
  const handleRestoreDocument = async (doc: Document) => {
    const response = await fetch(`${API_URL}/v1/documents/restore`, {
      method: "POST", credentials: "include", headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" },
      body: JSON.stringify({ documentId: doc.id }),
    }).catch(() => null);
    if (!response?.ok) {
      setToast("That document could not be restored.");
      setToastType("error");
      return;
    }
    setDeletedDocs((prev) => prev.filter((d) => d.id !== doc.id));
    setDocuments((prev) => [doc, ...prev]);
    setToast(`'${doc.title}' restored to your vault successfully.`);
    setToastType("success");
    const newLog: AuditEntry = {
      id: Date.now(),
      time: new Date().toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }) + ", " + new Date().toLocaleTimeString("en-ZA", { hour: "2-digit", minute: "2-digit" }),
      actor: "Student",
      action: "Document Restored",
      detail: `'${doc.title}' recovered from recycle bin and re-indexed.`,
      category: "Document"
    };
    setAuditLogs((prev) => [newLog, ...prev]);
  };

  // Passkeys are a later provider-backed feature; never bypass server authentication.
  const handleBiometricLogin = () => {
    setToast("Passkey sign-in will be enabled after the server-backed WebAuthn flow is added.");
    setToastType("info");
  };

  // Calendar helpers
  const getDaysInMonth = (date: Date) => new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
  const getFirstDayOfMonth = (date: Date) => new Date(date.getFullYear(), date.getMonth(), 1).getDay();
  const getDeadlinesForDay = (day: number) => {
    return deadlines.filter((d) => {
      const parts = d.due.split(" ");
      if (parts.length < 3) return false;
      const monthNames = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      const dueMonth = monthNames.indexOf(parts[1]);
      const dueDay = parseInt(parts[0]);
      const dueYear = parseInt(parts[2]);
      return dueDay === day && dueMonth === calendarMonth.getMonth() && dueYear === calendarMonth.getFullYear();
    });
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

  const complianceConfidence = useMemo(() => {
    const related = documents.filter((document) => /compliance|popia|privacy|regulat|requirement|obligation|eligib|policy|condition/i.test(`${document.title} ${document.summary} ${document.rawText || ""}`));
    return related.length ? Math.min(...related.map((document) => document.confidence)) : null;
  }, [documents]);


  if (authStep === "checking") {
    return <main className="login-page"><div className="login-card"><div className="brand"><span><FolderOpen size={19} /></span><div><b>Folio</b><small>Checking your secure session...</small></div></div></div></main>;
  }

  // Login and registration screen render
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
          <h1>{authMode === "register" ? "Create your secure Folio." : "Your funding paperwork, finally clear."}</h1>
          <p>Securely store, analyze and act on every document that keeps your studies moving.</p>

          <form onSubmit={handleCredentialsSubmit} className="login-form">
            {authMode === "register" && <label>
              Full Name
              <input value={displayNameInput} onChange={(e) => setDisplayNameInput(e.target.value)} placeholder="Your full name" autoComplete="name" required maxLength={120} />
            </label>}
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

            {authError && <div className="mfa-error-message"><AlertCircle size={14} /><span>{authError}</span></div>}

            <div className="mfa-notice">
              <ShieldCheck size={16} />
              <span>{authMode === "register" ? "We will verify your account by email before creating your session." : "A one-time email code is required after your password."}</span>
            </div>

            <button type="submit" className="primary full" disabled={authLoading}>
              {authLoading ? "Sending secure code..." : authMode === "register" ? "Register securely" : "Sign in securely"} <ArrowRight size={15} style={{ marginLeft: 6 }} />
            </button>
          </form>

          <button className="link" type="button" onClick={() => { setAuthMode(authMode === "login" ? "register" : "login"); setAuthError(""); }}>
            {authMode === "login" ? "New to Folio? Create an account" : "Already registered? Sign in"}
          </button>

          <div className="biometric-divider">
            <span>or</span>
          </div>

          <button className="biometric-login-btn" onClick={handleBiometricLogin} disabled={biometricScanning}>
            {biometricScanning ? (
              <>
                <ScanFace size={20} className={biometricDone ? "" : "pulse-scan"} style={{ color: biometricDone ? "var(--success)" : "var(--teal)" }} />
                <span>{biometricDone ? "Identity Verified" : "Scanning face..."}</span>
              </>
            ) : (
              <>
                <Fingerprint size={20} style={{ color: "var(--teal)" }} />
                <span>Passkey sign-in (coming after account setup)</span>
              </>
            )}
          </button>

          <small className="login-foot">
            POPIA-aligned by design · AWS deployment-ready architecture
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
            <p>We sent a 6-digit code to your email. Enter it to {authMode === "register" ? "verify your account and sign in" : "authorize your session"}.</p>
          </div>

          <div className="mfa-digits-container">
            {mfaDigits.map((digit, i) => (
              <input
                key={i}
                ref={(el) => { mfaRefs.current[i] = el; }}
                type="text"
                maxLength={1}
                inputMode="numeric"
                autoComplete={i === 0 ? "one-time-code" : "off"}
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

          <button onClick={() => handleVerifyMfa()} disabled={authLoading} className="primary full" style={{ marginTop: 10 }}>
            {authLoading ? "Verifying..." : authMode === "register" ? "Verify account & sign in" : "Authorize Session"}
          </button>

          <div className="mfa-timer-row">
            {mfaTimer > 0 ? (
              <span className="mfa-countdown-text">You can request a new code in <b>{mfaTimer}s</b></span>
            ) : (
              <span className="mfa-countdown-expired">Didn&apos;t get it? You can request a new code.</span>
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

          <button className="link" onClick={() => { setAuthStep("credentials"); setMfaError(""); }}>Back to {authMode === "register" ? "registration" : "sign in"}</button>
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
            <small>Financial documents understood · AWS-ready</small>
          </div>
        </div>

        <nav>
          {navItems.map(([key, label, Icon]) => (
            <button
              className={screen === key || (screen === "documents" && selectedDoc && key === "documents") ? "active" : ""}
              key={key}
              aria-current={screen === key || (screen === "documents" && selectedDoc && key === "documents") ? "page" : undefined}
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
            <span>{initials(authUser?.displayName || "Student")}</span>
            <div>
              <b>{authUser?.displayName || "Student"}</b>
              <small>Verified student account</small>
            </div>
          </div>
          <button onClick={handleLogout} className="signout-button">
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

          <button className="mobile-search-trigger mobile-only" type="button" onClick={() => { setMobileSearchOpen(true); setSearchOpen(true); }} aria-label="Search documents and ask Folio AI">
            <Search size={16} /> <span>Search</span>
          </button>

          <div className="search desktop-only nl-search-wrapper">
            <Search size={15} />
            <input
              aria-label="Search your documents"
              aria-autocomplete="list"
              aria-expanded={searchOpen && searchQuery.trim().length > 0}
              placeholder="Search documents or ask a question"
              value={searchQuery}
              onChange={(e) => { handleNLSearch(e.target.value); setSearchOpen(true); }}
              onFocus={() => searchQuery && setSearchOpen(true)}
              onKeyDown={(e) => {
                if (e.key === "Escape") {
                  setSearchOpen(false);
                  e.currentTarget.blur();
                }
              }}
              onBlur={() => setTimeout(() => setSearchOpen(false), 200)}
            />
            {searchQuery && (
              <button
                className="search-clear-btn"
                type="button"
                aria-label="Clear search"
                onMouseDown={(e) => e.preventDefault()}
                onClick={() => { setSearchQuery(""); setSearchResults([]); setSearchOpen(false); }}
              >
                <X size={14} />
              </button>
            )}
            <button
              className={`voice-search-btn ${voiceSearchActive ? "voice-active" : ""}`}
              aria-label={voiceSearchActive ? "Stop voice search" : "Start voice search"}
              onClick={() => voiceSearchActive ? stopVoiceInput() : handleVoiceInput("search")}
              title="Voice search"
            >
              {voiceSearchActive ? <MicOff size={13} /> : <Mic size={13} />}
            </button>
            {voiceSearchActive && <button className="voice-stop-btn" type="button" onClick={stopVoiceInput}><MicOff size={12} /> Stop</button>}
            {voiceSearchActive && <span className="voice-status search-voice-status" role="status"><i />{voiceStatus === "transcribing" ? "Transcribing" : "Listening"}</span>}
            {searchOpen && searchResults.length > 0 && (
              <div className="nl-search-results animate-slide-up">
                {searchResults.map((result, idx) => (
                  <button key={idx} className="nl-result-item" onClick={result.action}>
                    <span className={`nl-result-type-dot ${result.type}`} />
                    <div>
                      <b>{result.title}</b>
                      <small>{result.detail}</small>
                    </div>
                    <ChevronRight size={12} className="muted" style={{ marginLeft: "auto", flexShrink: 0 }} />
                  </button>
                ))}
              </div>
            )}
            {searchOpen && searchQuery.length > 1 && searchResults.length === 0 && (
              <div className="nl-search-results animate-slide-up">
                <div className="nl-no-results"><small>No matching documents found.</small></div>
              </div>
            )}
          </div>

          {mobileSearchOpen && (
            <div className="mobile-search-sheet" role="dialog" aria-modal="true" aria-label="Search Folio documents">
              <div className="mobile-search-sheet-head"><b>Search your vault</b><button type="button" aria-label="Close search" onClick={() => { setMobileSearchOpen(false); setSearchOpen(false); }}><X size={18} /></button></div>
              <div className="search mobile-search-input nl-search-wrapper">
                <Search size={16} />
                <input autoFocus aria-label="Search your documents" placeholder="Try “graduate job application”" value={searchQuery} onChange={(e) => { handleNLSearch(e.target.value); setSearchOpen(true); }} />
                <button className={`voice-search-btn ${voiceSearchActive ? "voice-active" : ""}`} type="button" aria-label={voiceSearchActive ? "Stop voice search" : "Start voice search"} onClick={() => voiceSearchActive ? stopVoiceInput() : handleVoiceInput("search")}>{voiceSearchActive ? <MicOff size={14} /> : <Mic size={14} />}</button>
                {voiceSearchActive && <button className="voice-stop-btn" type="button" onClick={stopVoiceInput}><MicOff size={12} /> Stop</button>}
              </div>
              {voiceSearchActive && <p className="voice-status mobile-voice-status" role="status"><i />{voiceStatus === "transcribing" ? "Transcribing your search" : "Listening for your search"}</p>}
              <p className="mobile-search-help">Use voice where available, or type any question. Results are grounded in your Folio documents.</p>
              {searchResults.length > 0 ? <div className="mobile-search-results">{searchResults.map((result, idx) => <button key={idx} className="nl-result-item" onClick={result.action}><span className={`nl-result-type-dot ${result.type}`} /><div><b>{result.title}</b><small>{result.detail}</small></div><ChevronRight size={14} className="muted" style={{ marginLeft: "auto", flexShrink: 0 }} /></button>)}</div> : searchQuery.length > 1 && <div className="mobile-search-results"><div className="nl-no-results"><small>Try a topic such as funding, renewal, fees, registration, or bank confirmation.</small></div></div>}
            </div>
          )}

          <div className="header-actions">
            <div className="popia-compliant-pill desktop-only">
              <ShieldCheck size={13} />
              <span>POPIA aligned · AWS-ready</span>
            </div>

            {deadlines.some(d => !d.completed) && <div style={{ position: "relative" }}>
              <button className="notification" aria-label="View pending deadlines" aria-expanded={notifOpen} onClick={() => { setNotifOpen(!notifOpen); setMobileProfileOpen(false); }}>
                <Bell size={17} />
                {deadlines.filter(d => !d.completed).length > 0 && <em />}
              </button>
              {notifOpen && (
                <div className="notif-dropdown animate-slide-up">
                  <div className="notif-dropdown-header"><b>Pending Obligations</b></div>
                  {deadlines.filter(d => !d.completed).length === 0 ? (
                    <div className="notif-empty"><small>All obligations resolved.</small></div>
                  ) : (
                    deadlines.filter(d => !d.completed).map(d => (
                      <button key={d.id} className="notif-item" onClick={() => { setScreen("deadlines"); setNotifOpen(false); }}>
                        <span className={`severity ${d.severity}`} />
                        <div>
                          <b>{d.action}</b>
                          <small>Due: {d.due} · {d.days} days</small>
                        </div>
                      </button>
                    ))
                  )}
                </div>
              )}
            </div>}

            {/* Profile Dropdown Trigger for Mobile & Desktop */}
            <button className="profile-header-chip" aria-label="Open account menu" aria-expanded={mobileProfileOpen} onClick={() => setMobileProfileOpen(!mobileProfileOpen)}>
              <span>{initials(authUser?.displayName || "Student")}</span>
              <div className="desktop-only">
                <b>{authUser?.displayName || "Student"}</b>
                <small>Student Account</small>
              </div>
            </button>

            {/* Quick Profile Sheet for Mobile/Desktop */}
            {mobileProfileOpen && (
              <div className="quick-profile-dropdown animate-slide-up">
                <div className="dropdown-profile-header">
                  <b>{authUser?.displayName || "Student"}</b>
                  <p>{authUser?.email}</p>
                  <small>Student Account</small>
                </div>
                <button
                  className="dropdown-item signout"
                  onClick={handleLogout}
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
                  <h1>Welcome back, {(authUser?.displayName || "Student").split(" ")[0]}</h1>
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

                {deadlines.length > 0 && <div className="stat-card">
                  <div className="stat-icon" style={{ color: "#c97a2b", background: "#fbede0" }}>
                    <AlertTriangle size={18} />
                  </div>
                  <div>
                    <strong>{deadlines.filter(d => !d.completed).length}</strong>
                    <span>Pending Obligations</span>
                  </div>
                </div>}

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
                    <strong>{complianceConfidence == null ? "—" : `${complianceConfidence}%`}</strong>
                    <span>Compliance Confidence</span>
                  </div>
                </div>
              </div>

              <div className={`columns animate-slide-up ${deadlines.length === 0 ? "single-column" : ""}`} style={{ animationDelay: "0.1s" }}>
                {/* Timeline Obligations */}
                {deadlines.length > 0 && <div className="panel">
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
                </div>}

                {/* AI Grounded Prompt Shortcut */}
                <div className="panel">
                  <div className="panel-heading">
                    <b>Ask AI Assistant</b>
                  </div>

                  <button className="ask-prompt" onClick={() => { setInput("What should I pay attention to in my documents?"); setScreen("ask"); }}>
                    <span><MessageSquareText size={18} /></span>
                    <div>
                      <b>&quot;What should I pay attention to?&quot;</b>
                      <small>Ask open-ended questions and inspect the document sources behind each answer.</small>
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
                <div style={{ display: "flex", gap: 8 }}>
                  <button
                    className="secondary"
                    onClick={() => setShowRecycleBin(!showRecycleBin)}
                    style={{ position: "relative" }}
                  >
                    <ArchiveRestore size={15} style={{ marginRight: 6 }} />
                    Recovery Bin
                    {deletedDocs.length > 0 && (
                      <span className="recycle-badge">{deletedDocs.length}</span>
                    )}
                  </button>
                  <button className="primary" onClick={() => setUploadOpen(true)}>
                    <UploadCloud size={16} style={{ marginRight: 6 }} /> Upload paperwork
                  </button>
                </div>
              </div>

              {showRecycleBin && deletedDocs.length > 0 && (
                <div className="recycle-bin-panel animate-slide-up">
                  <div className="panel-heading">
                    <b><Trash2 size={13} style={{ marginRight: 5 }} /> Recycle Bin — Recoverable Documents</b>
                  </div>
                  {deletedDocs.map((doc) => (
                    <div key={doc.id} className="recycle-doc-row">
                      <FileText size={14} style={{ color: "var(--slate)", flexShrink: 0 }} />
                      <div className="recycle-doc-info">
                        <b>{doc.title}</b>
                        <small>{doc.type} · {doc.date}</small>
                      </div>
                      <button className="restore-btn" onClick={() => handleRestoreDocument(doc)}>
                        <ArchiveRestore size={13} style={{ marginRight: 5 }} /> Restore
                      </button>
                    </div>
                  ))}
                </div>
              )}
              {showRecycleBin && deletedDocs.length === 0 && (
                <div className="recycle-bin-panel animate-slide-up">
                  <div className="empty-audit-logs"><small>Recycle bin is empty.</small></div>
                </div>
              )}

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
                  <button
                    className="delete-doc-btn"
                    style={{ marginTop: 8 }}
                    onClick={() => handleDeleteDocument(selectedDoc)}
                  >
                    <Trash2 size={13} style={{ marginRight: 6 }} /> Move to Recycle Bin
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
                        <button className="secondary" onClick={() => handleFullScreen(selectedDoc)}><Eye size={12} /> Full Screen</button>
                        <button className="secondary" onClick={() => handleDownloadOCR(selectedDoc)}><Download size={12} /> Download OCR</button>
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
                    <span><b>POPIA Restricted Session:</b> Access to original file blocks is logged under the authenticated session. The architecture remains ready for AWS KMS and S3 deployment.</span>
                  </div>
                </div>
              </div>
            </section>
          )}

          {/* SCREEN: ASK AI (GROUNDED CONVERSATIONAL CHAT) */}
          {screen === "ask" && (
            <section className="screen chat-screen animate-fade-in">
              <div className="screen-heading split">
                <div>
                  <label>Folio AI · Document grounded</label>
                  <h1>Ask anything about your documents</h1>
                </div>
              </div>

              <div className="chat">
                <div className="chat-log" ref={chatLogRef}>
                  {chatMessages.map((msg, idx) => msg.text ? (
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
                              <button
                                className="citation-chip-badge citation-clickable"
                                key={sIdx}
                                onClick={() => handleCitationClick(src.doc)}
                                title="Click to open source document"
                              >
                                <FileText size={10} style={{ marginRight: 4 }} />
                                <span>{src.doc} · {src.detail}</span>
                              </button>
                            ))}
                          </div>
                        )}
                        {typeof msg.complianceConfidence === "number" && (
                          <div className="compliance-confidence">
                            <span><ShieldCheck size={12} /> Compliance confidence {msg.complianceConfidence}%</span>
                            <details>
                              <summary aria-label="How compliance confidence is calculated"><Info size={13} /></summary>
                              <p>{msg.complianceLogic}</p>
                            </details>
                          </div>
                        )}
                        {msg.role === "assistant" && msg.text && (
                          <button
                            className="speak-btn"
                            onClick={() => speakText(msg.text)}
                            title="Read aloud"
                          >
                            🔊
                          </button>
                        )}
                      </div>
                    </div>
                  ) : null)}
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

                {chatMessages.length === 1 && <div className="suggestions">
                  {["Summarise my documents", "What needs my attention?", "Compare the conditions", "Draft my next steps"].map((suggestion) => (
                    <button key={suggestion} onClick={() => handleSendChat(suggestion)}>
                      {suggestion}
                    </button>
                  ))}
                </div>}

                {voiceActive && <p className="voice-status chat-voice-status" role="status"><i />{voiceStatus === "transcribing" ? "Transcribing your question — you can edit it when ready." : "Listening — your words appear here as you speak."}</p>}
                <div className="chat-input">
                  <button
                    className={`voice-chat-btn ${voiceActive ? "voice-active" : ""}`}
                    onClick={() => voiceActive ? stopVoiceInput() : handleVoiceInput("chat")}
                    title="Speak your question"
                  >
                    {voiceActive ? <MicOff size={15} /> : <Mic size={15} />}
                  </button>
                  <textarea
                    value={chatInput}
                    onChange={(e) => setInput(e.target.value)}
                    onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSendChat(); } }}
                    placeholder={voiceActive ? "Listening..." : "Message Folio AI"}
                    aria-label="Message Folio AI"
                    rows={1}
                  />
                  {voiceActive && <button className="voice-stop-btn chat-stop-btn" type="button" onClick={stopVoiceInput}><MicOff size={13} /> Stop</button>}
                  <button className="primary" onClick={() => handleSendChat()} disabled={aiTyping}>
                    <Send size={15} />
                  </button>
                </div>
              </div>
            </section>
          )}

          {/* SCREEN: DEADLINES */}
          {screen === "deadlines" && (
            <section className="screen animate-fade-in">
              <div className="screen-heading split">
                <div>
                  <label>Timeline Schedule</label>
                  <h1>Active Student Obligations</h1>
                  <p>Obligations automatically parsed and timeline schedule updated dynamically from document extractions.</p>
                </div>
                <div className="deadline-view-toggle">
                  <button
                    className={deadlineView === "timeline" ? "active" : ""}
                    onClick={() => setDeadlineView("timeline")}
                  >
                    <Clock3 size={13} style={{ marginRight: 5 }} /> Timeline
                  </button>
                  <button
                    className={deadlineView === "calendar" ? "active" : ""}
                    onClick={() => setDeadlineView("calendar")}
                  >
                    <CalendarDays size={13} style={{ marginRight: 5 }} /> Calendar
                  </button>
                </div>
              </div>

              {deadlineView === "timeline" && (
                <div className="timeline-layout">
                  {deadlines.length === 0 && (
                    <div className="panel empty-timeline-state">
                      <Clock3 size={24} />
                      <b>No document deadlines yet</b>
                      <small>When Folio identifies a dated obligation in an uploaded document, it will appear here for your review.</small>
                    </div>
                  )}
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
              )}

              {deadlineView === "calendar" && (
                <div className="calendar-panel animate-fade-in">
                  <div className="calendar-nav">
                    <button className="secondary" onClick={() => setCalendarMonth(new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() - 1, 1))}>
                      <ChevronLeft size={14} />
                    </button>
                    <b>{calendarMonth.toLocaleString("en-ZA", { month: "long", year: "numeric" })}</b>
                    <button className="secondary" onClick={() => setCalendarMonth(new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + 1, 1))}>
                      <ChevronRight size={14} />
                    </button>
                  </div>

                  <div className="calendar-grid">
                    {["Sun","Mon","Tue","Wed","Thu","Fri","Sat"].map((d) => (
                      <div key={d} className="calendar-day-header">{d}</div>
                    ))}
                    {Array.from({ length: getFirstDayOfMonth(calendarMonth) }).map((_, i) => (
                      <div key={`empty-${i}`} className="calendar-day empty" />
                    ))}
                    {Array.from({ length: getDaysInMonth(calendarMonth) }).map((_, i) => {
                      const day = i + 1;
                      const dayDeadlines = getDeadlinesForDay(day);
                      return (
                        <div key={day} className={`calendar-day ${dayDeadlines.length > 0 ? "has-deadline" : ""}`}>
                          <span className="calendar-day-num">{day}</span>
                          {dayDeadlines.map((d) => (
                            <div key={d.id} className={`calendar-event-dot ${d.severity}`} title={d.action}>
                              <small>{d.action.substring(0, 18)}{d.action.length > 18 ? "..." : ""}</small>
                            </div>
                          ))}
                        </div>
                      );
                    })}
                  </div>

                  <div className="calendar-legend">
                    <span className="legend-dot high" /> High priority &nbsp;
                    <span className="legend-dot medium" /> Medium &nbsp;
                    <span className="legend-dot low" /> Low
                  </div>
                </div>
              )}
            </section>
          )}

          {/* SCREEN: SECURITY & AUDIT (POPIA FOCUS) */}
          {screen === "security" && (
            <section className="screen animate-fade-in">
              <div className="screen-heading">
                <label>Compliance Hub</label>
                <h1>POPIA Compliance & Encryption Control</h1>
                <p>Folio is designed to support POPIA-aligned handling of your private documents and account activity.</p>
              </div>

              <div className="columns security-grid">
                {/* Security and Governance Controls */}
                <div className="panel">
                  <div className="panel-heading">
                    <b>Data Governance Controls</b>
                  </div>

                  <div className="security-settings-stack">
                    <div className="setting-control-row">
                      <div>
                        <b>Multi-factor Auth (MFA)</b>
                        <small>Email OTP verification protects registration and sign-in.</small>
                      </div>
                      <button aria-label="Toggle multi-factor authentication" aria-pressed={mfaEnabled} className={`toggle ${mfaEnabled ? "on" : ""}`} onClick={() => { setMfaEnabled(!mfaEnabled); setToast(mfaEnabled ? "MFA disabled — not recommended." : "MFA re-enabled. Session secured."); }}><span /></button>
                    </div>

                    <div className="setting-control-row">
                      <div>
                        <b>Native Biometric Lock</b>
                        <small>Available when Folio&apos;s native passkey flow is connected.</small>
                      </div>
                      <button aria-label="Toggle native biometric lock" aria-pressed={biometricEnabled} className={`toggle ${biometricEnabled ? "on" : ""}`} onClick={() => { setBiometricEnabled(!biometricEnabled); setToast(biometricEnabled ? "Biometric lock disabled." : "Biometric lock preference enabled."); }}><span /></button>
                    </div>

                    <div className="setting-control-row">
                      <div>
                        <b>Financial Aid Data Share</b>
                        <small>Grant temporary summary review access to student advisor.</small>
                      </div>
                      <button aria-label="Toggle financial aid data sharing" aria-pressed={sharing} className={`toggle ${sharing ? "on" : ""}`} onClick={() => setSharing(!sharing)}>
                        <span />
                      </button>
                    </div>
                  </div>

                  <div className="security-notice-box-gold">
                    <LockKeyhole size={14} style={{ flexShrink: 0, marginTop: 1 }} />
                    <div>
                      <b>AWS KMS + S3 deployment-ready</b>
                      <p>Folio currently uses private signed storage. Its production architecture is prepared for AWS KMS-managed encryption and private S3 object access.</p>
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
        <nav className="mobile-bottom-navigation-bar" aria-label="Primary navigation">
          {navItems.map(([key, label, Icon]) => (
            <button
              key={key}
              className={screen === key || (screen === "documents" && selectedDoc && key === "documents") ? "active" : ""}
              aria-label={label}
              aria-current={screen === key || (screen === "documents" && selectedDoc && key === "documents") ? "page" : undefined}
              onClick={() => {
                setScreen(key);
                setSelectedDoc(null);
              }}
            >
              <Icon size={18} />
              <span>{label}</span>
            </button>
          ))}
        </nav>
      </div>

      {/* MODAL: SECURE PAPERWORK UPLOAD FLOW */}
      {uploadOpen && (
        <div className="modal-backdrop animate-fade-in" onClick={() => { setUploadOpen(false); setUploadStep("idle"); setUploadFileName(""); setUploadFile(null); }}>
          <div className="modal animate-slide-up" role="dialog" aria-modal="true" aria-labelledby="upload-dialog-title" onClick={(e) => e.stopPropagation()}>
            <div className="modal-heading">
              <b id="upload-dialog-title">Secure Document Dispatch</b>
              <button className="close-modal-btn" aria-label="Close upload dialog" onClick={() => { setUploadOpen(false); setUploadStep("idle"); setUploadFileName(""); setUploadFile(null); setUploadTitle(""); if (fileInputRef.current) fileInputRef.current.value = ""; }}>
                <X size={17} />
              </button>
            </div>

            {uploadStep === "idle" ? (
              <div className="upload-interactive-form">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".pdf,.docx,.png,.jpg,.jpeg"
                  style={{ display: "none" }}
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) {
                      setUploadFile(file);
                      setUploadFileName(file.name);
                      if (!uploadTitle.trim()) {
                        setUploadTitle(file.name.replace(/\.[^.]+$/, ""));
                      }
                    }
                  }}
                />
                <div
                  className={`dropzone ${uploadFileName ? "dropzone-filled" : ""}`}
                  role="button"
                  tabIndex={0}
                  aria-label={uploadFileName ? "Change selected document" : "Select a document to upload"}
                  onClick={() => fileInputRef.current?.click()}
                  onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); fileInputRef.current?.click(); } }}
                  onDragOver={(e) => e.preventDefault()}
                  onDrop={(e) => {
                    e.preventDefault();
                    const file = e.dataTransfer.files?.[0];
                    if (file) {
                      setUploadFile(file);
                      setUploadFileName(file.name);
                      if (!uploadTitle.trim()) setUploadTitle(file.name.replace(/\.[^.]+$/, ""));
                    }
                  }}
                >
                  {uploadFileName ? (
                    <>
                      <CheckCircle size={28} style={{ color: "var(--success)" }} />
                      <b style={{ color: "var(--success)" }}>{uploadFileName}</b>
                      <small>File selected — click to change</small>
                    </>
                  ) : (
                    <>
                      <UploadCloud size={32} style={{ color: "var(--teal)" }} />
                      <b>Click or drag a PDF / document here</b>
                      <small>Max 20MB. Fully encrypted at rest.</small>
                    </>
                  )}
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
                  {uploadStep === "uploading" && "Uploading to your secure vault..."}
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
