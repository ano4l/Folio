import React, { useState, useEffect, useRef } from "react";
import {
  LayoutDashboard, FileText, MessageSquareText, Bell, ShieldCheck, UploadCloud,
  Search, ChevronRight, Paperclip, Clock, CheckCircle2, AlertTriangle, LogOut,
  Smartphone, Monitor, X, Send, Download, Eye, Lock, Sparkles, FolderOpen,
  Loader2, ArrowLeft, KeyRound, ScrollText, Fingerprint, ChevronDown
} from "lucide-react";

const TYPE_STYLE = {
  "NSFAS Award Letter": { bar: "#C97A2B", bg: "#FBEEE0", label: "NSFAS" },
  "Bursary Agreement": { bar: "#0E7C74", bg: "#E4F2F0", label: "Bursary" },
  "Fee Statement": { bar: "#33455E", bg: "#E8ECF1", label: "Fees" },
  "Bank Letter": { bar: "#6E5A7E", bg: "#EEE8F2", label: "Bank" },
  "Appeal Correspondence": { bar: "#C97A2B", bg: "#FBEEE0", label: "Appeal" },
};

const SEED_DOCS = [
  {
    id: 1,
    title: "NSFAS Award Letter — 2026",
    type: "NSFAS Award Letter",
    date: "14 Jan 2026",
    pages: 3,
    status: "Ready",
    confidence: 96,
    summary:
      "Confirms full NSFAS funding for the 2026 academic year, covering tuition, accommodation and a book allowance. Funding continues only if a 60% average is maintained and you remain registered full time. Proof of registration must be submitted within 30 days of the start of term.",
    entities: [
      { label: "Award amount", value: "R98,450" },
      { label: "Condition", value: "Maintain 60% average" },
      { label: "Action required", value: "Submit proof of registration by 12 Feb 2026" },
    ],
  },
  {
    id: 2,
    title: "Eduvos Merit Bursary Agreement",
    type: "Bursary Agreement",
    date: "02 Feb 2026",
    pages: 5,
    status: "Ready",
    confidence: 91,
    summary:
      "Sets out a partial tuition bursary, renewable annually, conditional on submitting an updated academic transcript and a signed renewal declaration before the renewal window closes.",
    entities: [
      { label: "Bursary value", value: "R32,000 / year" },
      { label: "Renewal due", value: "02 Aug 2026" },
      { label: "Requirement", value: "Transcript + signed declaration" },
    ],
  },
  {
    id: 3,
    title: "Semester 1 Fee Statement",
    type: "Fee Statement",
    date: "20 Jan 2026",
    pages: 2,
    status: "Ready",
    confidence: 98,
    summary:
      "Itemises tuition, residence and meal plan charges for Semester 1, less the NSFAS payment already received. An outstanding balance is due before the exam period begins.",
    entities: [
      { label: "Balance due", value: "R4,120" },
      { label: "Due date", value: "28 Feb 2026" },
    ],
  },
  {
    id: 4,
    title: "Standard Bank Account Confirmation",
    type: "Bank Letter",
    date: "11 Jan 2026",
    pages: 1,
    status: "Ready",
    confidence: 99,
    summary:
      "Confirms the student's account details for NSFAS disbursement purposes. No conditions or further action required.",
    entities: [{ label: "Purpose", value: "Disbursement verification" }],
  },
];

const DEADLINES = [
  { doc: "NSFAS Award Letter — 2026", action: "Submit proof of registration", due: "12 Feb 2026", days: 3, severity: "high" },
  { doc: "Eduvos Merit Bursary Agreement", action: "Submit transcript & renewal declaration", due: "02 Aug 2026", days: 9, severity: "medium" },
  { doc: "Semester 1 Fee Statement", action: "Settle outstanding balance", due: "28 Feb 2026", days: 14, severity: "low" },
];

const AUDIT_LOG = [
  { time: "24 Jul 2026, 09:12", actor: "Londiwe M.", action: "Viewed", detail: "NSFAS Award Letter — 2026" },
  { time: "23 Jul 2026, 18:41", actor: "Londiwe M.", action: "Asked AI", detail: "\u201cWhen is my bursary renewal?\u201d" },
  { time: "20 Jul 2026, 08:03", actor: "System", action: "Encrypted at rest", detail: "Semester 1 Fee Statement (S3, SSE)" },
  { time: "14 Jan 2026, 14:55", actor: "Londiwe M.", action: "Uploaded", detail: "NSFAS Award Letter — 2026" },
];

function initials(name) {
  return name.split(" ").map((n) => n[0]).join("").slice(0, 2).toUpperCase();
}

function TypeTag({ type }) {
  const s = TYPE_STYLE[type] || TYPE_STYLE["Fee Statement"];
  return (
    <span className="tag" style={{ background: s.bg, color: s.bar }}>
      {s.label}
    </span>
  );
}

function Toast({ text }) {
  if (!text) return null;
  return (
    <div className="toast">
      <CheckCircle2 size={16} style={{ color: "#0E7C74" }} />
      <span>{text}</span>
    </div>
  );
}

function StatCard({ icon: Icon, label, value, tint }) {
  return (
    <div className="stat-card">
      <div className="stat-icon" style={{ background: tint + "22", color: tint }}>
        <Icon size={18} />
      </div>
      <div>
        <div className="stat-value">{value}</div>
        <div className="stat-label">{label}</div>
      </div>
    </div>
  );
}

function DocCard({ doc, onOpen }) {
  const s = TYPE_STYLE[doc.type] || TYPE_STYLE["Fee Statement"];
  return (
    <button className="doc-card" onClick={() => onOpen(doc)}>
      <div className="doc-tab" style={{ background: s.bar }} />
      <div className="doc-card-body">
        <div className="doc-card-top">
          <TypeTag type={doc.type} />
          {doc.status === "Processing" ? (
            <span className="proc-pill">
              <Loader2 size={12} className="spin" /> Processing
            </span>
          ) : (
            <span className="ready-pill">Analysed</span>
          )}
        </div>
        <div className="doc-title">{doc.title}</div>
        <div className="doc-meta">
          {doc.date} · {doc.pages} page{doc.pages > 1 ? "s" : ""}
        </div>
        {doc.status === "Ready" && <div className="doc-summary-preview">{doc.summary}</div>}
      </div>
      <ChevronRight size={18} className="doc-chevron" />
    </button>
  );
}

function LoginScreen({ onLogin }) {
  return (
    <div className="login-wrap">
      <div className="login-card">
        <div className="login-brand">
          <div className="brand-mark">
            <FolderOpen size={20} />
          </div>
          <div>
            <div className="brand-name">Folio</div>
            <div className="brand-sub">Student financial documents, understood.</div>
          </div>
        </div>
        <div className="login-field">
          <label>Student email</label>
          <input defaultValue="londiwe.m@eduvos-student.ac.za" readOnly />
        </div>
        <div className="login-field">
          <label>Password</label>
          <input type="password" defaultValue="••••••••••" readOnly />
        </div>
        <div className="login-mfa">
          <ShieldCheck size={14} /> Multi-factor authentication via Eduvos SSO (OAuth 2.0 / OIDC)
        </div>
        <button className="btn-primary full" onClick={onLogin}>
          Sign in securely
        </button>
        <div className="login-foot">
          Protected under POPIA. Your documents are encrypted at rest and in transit, and only you can view them.
        </div>
      </div>
    </div>
  );
}

function Dashboard({ docs, onOpen, goto, name }) {
  const ready = docs.filter((d) => d.status === "Ready").length;
  return (
    <div className="screen">
      <div className="screen-head">
        <div>
          <div className="eyebrow">Overview</div>
          <h1>Good afternoon, {name.split(" ")[0]}</h1>
          <p className="sub">Here's where your financial documents and deadlines stand today.</p>
        </div>
      </div>

      <div className="stat-grid">
        <StatCard icon={FileText} label="Documents on file" value={docs.length} tint="#0E7C74" />
        <StatCard icon={AlertTriangle} label="Deadlines this month" value="3" tint="#C97A2B" />
        <StatCard icon={Sparkles} label="AI insights ready" value={ready} tint="#33455E" />
        <StatCard icon={ShieldCheck} label="Security status" value="Protected" tint="#2F855A" />
      </div>

      <div className="two-col">
        <div className="panel">
          <div className="panel-head">
            <span>Upcoming deadlines</span>
            <button className="link" onClick={() => goto("deadlines")}>
              View all
            </button>
          </div>
          {DEADLINES.map((d, i) => (
            <div className="deadline-row" key={i}>
              <div className={"sev-dot sev-" + d.severity} />
              <div className="deadline-info">
                <div className="deadline-action">{d.action}</div>
                <div className="deadline-doc">{d.doc}</div>
              </div>
              <div className="deadline-due">
                <div>{d.due}</div>
                <div className="deadline-days">{d.days} days left</div>
              </div>
            </div>
          ))}
        </div>

        <div className="panel">
          <div className="panel-head">
            <span>Ask about your documents</span>
          </div>
          <div className="ask-teaser" onClick={() => goto("ask")}>
            <div className="ask-teaser-icon">
              <MessageSquareText size={18} />
            </div>
            <div>
              <div className="ask-teaser-title">"When is my bursary renewal due?"</div>
              <div className="ask-teaser-sub">Get a grounded answer with sources from your own documents — not a guess.</div>
            </div>
            <ChevronRight size={16} />
          </div>
          <div className="panel-head" style={{ marginTop: 18 }}>
            <span>Recent documents</span>
            <button className="link" onClick={() => goto("documents")}>
              View all
            </button>
          </div>
          <div className="doc-list-mini">
            {docs.slice(0, 2).map((d) => (
              <DocCard key={d.id} doc={d} onOpen={onOpen} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function DocumentsScreen({ docs, onOpen, onUploadClick }) {
  const [filter, setFilter] = useState("All");
  const types = ["All", ...Object.keys(TYPE_STYLE)];
  const shown = filter === "All" ? docs : docs.filter((d) => d.type === filter);
  return (
    <div className="screen">
      <div className="screen-head row">
        <div>
          <div className="eyebrow">Document vault</div>
          <h1>Your documents</h1>
          <p className="sub">Every financial document, classified, summarised and searchable.</p>
        </div>
        <button className="btn-primary" onClick={onUploadClick}>
          <UploadCloud size={16} /> Upload document
        </button>
      </div>

      <div className="filter-row">
        {types.map((t) => (
          <button key={t} className={"chip-filter" + (filter === t ? " active" : "")} onClick={() => setFilter(t)}>
            {t === "All" ? "All" : TYPE_STYLE[t].label}
          </button>
        ))}
      </div>

      <div className="doc-list">
        {shown.map((d) => (
          <DocCard key={d.id} doc={d} onOpen={onOpen} />
        ))}
        {shown.length === 0 && <div className="empty">No documents of this type yet.</div>}
      </div>
    </div>
  );
}

function DocDetailScreen({ doc, back, goto }) {
  if (!doc) return null;
  const s = TYPE_STYLE[doc.type] || TYPE_STYLE["Fee Statement"];
  return (
    <div className="screen">
      <button className="back-link" onClick={back}>
        <ArrowLeft size={15} /> Back to documents
      </button>

      <div className="detail-head">
        <div className="detail-tab" style={{ background: s.bar }} />
        <div>
          <TypeTag type={doc.type} />
          <h1 style={{ marginTop: 8 }}>{doc.title}</h1>
          <p className="sub">
            {doc.date} · {doc.pages} pages · Uploaded to encrypted storage
          </p>
        </div>
      </div>

      <div className="two-col">
        <div className="panel">
          <div className="panel-head">
            <span>
              <Sparkles size={14} style={{ marginRight: 6, verticalAlign: -2 }} />
              AI summary
            </span>
            <span className="confidence">{doc.confidence}% extraction confidence</span>
          </div>
          <p className="summary-text">{doc.summary}</p>

          <div className="panel-head" style={{ marginTop: 16 }}>
            <span>Key details extracted</span>
          </div>
          <div className="entity-grid">
            {doc.entities.map((e, i) => (
              <div className="entity" key={i}>
                <div className="entity-label">{e.label}</div>
                <div className="entity-value">{e.value}</div>
              </div>
            ))}
          </div>

          <button className="btn-secondary full" style={{ marginTop: 16 }} onClick={() => goto("ask")}>
            <MessageSquareText size={15} /> Ask a question about this document
          </button>
        </div>

        <div className="panel">
          <div className="panel-head">
            <span>Source document</span>
          </div>
          <div className="doc-preview">
            <div className="doc-preview-page">
              <div className="fake-line w-70" />
              <div className="fake-line w-90" />
              <div className="fake-line w-60" />
              <div className="fake-line w-80" style={{ marginTop: 10 }} />
              <div className="fake-line w-95" />
              <div className="fake-line w-40" />
            </div>
            <div className="doc-preview-actions">
              <button className="icon-btn">
                <Eye size={14} /> Preview
              </button>
              <button className="icon-btn">
                <Download size={14} /> Download
              </button>
            </div>
          </div>
          <div className="notice-box">
            <Lock size={13} /> Only you can view this file. Access is logged for audit purposes.
          </div>
        </div>
      </div>
    </div>
  );
}

function answerFor(q) {
  const query = q.toLowerCase();
  if (query.includes("bursary") || query.includes("renew")) {
    return {
      text:
        "Your Eduvos Merit Bursary renews annually. To keep it active, submit an updated academic transcript together with a signed renewal declaration before 02 Aug 2026.",
      sources: [{ doc: "Eduvos Merit Bursary Agreement", loc: "Page 2, Renewal Conditions" }],
    };
  }
  if (query.includes("fee") || query.includes("owe") || query.includes("balance") || query.includes("pay")) {
    return {
      text:
        "Your Semester 1 statement shows an outstanding balance of R4,120 after your NSFAS payment was applied. This is due by 28 Feb 2026, before the exam period begins.",
      sources: [{ doc: "Semester 1 Fee Statement", loc: "Page 1, Balance Summary" }],
    };
  }
  if (query.includes("nsfas") || query.includes("average") || query.includes("condition") || query.includes("register")) {
    return {
      text:
        "Your NSFAS funding is conditional on maintaining a 60% average and staying registered full time. You'll also need to submit proof of registration by 12 Feb 2026 to keep the award active.",
      sources: [{ doc: "NSFAS Award Letter — 2026", loc: "Page 1, Funding Conditions" }],
    };
  }
  return {
    text:
      "Based on your documents, your most time-sensitive item is submitting proof of registration for NSFAS by 12 Feb 2026. Ask me about a specific document, like your bursary or fee statement, for more detail.",
    sources: [{ doc: "NSFAS Award Letter — 2026", loc: "Page 1, Funding Conditions" }],
  };
}

function AskScreen() {
  const [messages, setMessages] = useState([
    {
      role: "assistant",
      text:
        "Hi Londiwe — I can answer questions using only your own uploaded documents, and I'll always show you where the answer came from. What would you like to know?",
      sources: [],
    },
  ]);
  const [input, setInput] = useState("");
  const [thinking, setThinking] = useState(false);
  const endRef = useRef(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, thinking]);

  function send(text) {
    const q = (text ?? input).trim();
    if (!q) return;
    setMessages((m) => [...m, { role: "user", text: q }]);
    setInput("");
    setThinking(true);
    setTimeout(() => {
      const a = answerFor(q);
      setMessages((m) => [...m, { role: "assistant", text: a.text, sources: a.sources }]);
      setThinking(false);
    }, 950);
  }

  const suggestions = ["When is my bursary renewal?", "Do I still owe any fees?", "What are my NSFAS conditions?"];

  return (
    <div className="screen chat-screen">
      <div className="screen-head">
        <div className="eyebrow">Retrieval-augmented Q&A</div>
        <h1>Ask about your documents</h1>
        <p className="sub">Answers are grounded only in documents you've uploaded, with sources cited every time.</p>
      </div>

      <div className="chat-window">
        <div className="chat-log">
          {messages.map((m, i) => (
            <div key={i} className={"bubble-row " + (m.role === "user" ? "from-user" : "from-ai")}>
              {m.role === "assistant" && (
                <div className="bubble-avatar">
                  <Sparkles size={13} />
                </div>
              )}
              <div className="bubble">
                <div>{m.text}</div>
                {m.sources && m.sources.length > 0 && (
                  <div className="source-chips">
                    {m.sources.map((s, j) => (
                      <div className="source-chip" key={j}>
                        <Paperclip size={11} />
                        {s.doc} — {s.loc}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ))}
          {thinking && (
            <div className="bubble-row from-ai">
              <div className="bubble-avatar">
                <Sparkles size={13} />
              </div>
              <div className="bubble typing">
                <Loader2 size={13} className="spin" /> Searching your documents…
              </div>
            </div>
          )}
          <div ref={endRef} />
        </div>

        <div className="suggestion-row">
          {suggestions.map((s) => (
            <button key={s} className="suggestion-chip" onClick={() => send(s)}>
              {s}
            </button>
          ))}
        </div>

        <div className="chat-input-row">
          <input
            placeholder="Ask a question about your financial documents…"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && send()}
          />
          <button className="btn-primary" onClick={() => send()}>
            <Send size={15} />
          </button>
        </div>
      </div>
    </div>
  );
}

function DeadlinesScreen() {
  return (
    <div className="screen">
      <div className="screen-head">
        <div className="eyebrow">Timeline</div>
        <h1>Deadlines & actions</h1>
        <p className="sub">Auto-detected from your documents, so nothing important slips through.</p>
      </div>
      <div className="timeline">
        {DEADLINES.map((d, i) => (
          <div className="timeline-item" key={i}>
            <div className={"timeline-dot sev-" + d.severity} />
            {i < DEADLINES.length - 1 && <div className="timeline-line" />}
            <div className="timeline-card">
              <div className="timeline-top">
                <span className="timeline-due">{d.due}</span>
                <span className={"sev-pill sev-" + d.severity}>{d.days} days left</span>
              </div>
              <div className="timeline-action">{d.action}</div>
              <div className="timeline-doc">
                <FileText size={12} /> {d.doc}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function Toggle({ on, onChange }) {
  return (
    <button className={"toggle" + (on ? " on" : "")} onClick={() => onChange(!on)}>
      <span className="toggle-knob" />
    </button>
  );
}

function SecurityScreen() {
  const [mfa, setMfa] = useState(true);
  const [biometric, setBiometric] = useState(true);
  const [shareThirdParty, setShareThirdParty] = useState(false);

  return (
    <div className="screen">
      <div className="screen-head">
        <div className="eyebrow">Privacy & security</div>
        <h1>Your data, protected by design</h1>
        <p className="sub">Controls aligned to POPIA — data minimisation, encryption, and a full audit trail.</p>
      </div>

      <div className="two-col">
        <div className="panel">
          <div className="panel-head">
            <span>Controls</span>
          </div>
          <div className="setting-row">
            <div>
              <div className="setting-title">
                <KeyRound size={14} /> Multi-factor authentication
              </div>
              <div className="setting-sub">Required at sign-in via Eduvos SSO (OAuth 2.0 / OIDC)</div>
            </div>
            <Toggle on={mfa} onChange={setMfa} />
          </div>
          <div className="setting-row">
            <div>
              <div className="setting-title">
                <Fingerprint size={14} /> Biometric app lock
              </div>
              <div className="setting-sub">Face ID / fingerprint required to reopen the mobile app</div>
            </div>
            <Toggle on={biometric} onChange={setBiometric} />
          </div>
          <div className="setting-row">
            <div>
              <div className="setting-title">
                <ShieldCheck size={14} /> Share summaries with financial aid office
              </div>
              <div className="setting-sub">Off by default — nothing leaves your account without consent</div>
            </div>
            <Toggle on={shareThirdParty} onChange={setShareThirdParty} />
          </div>
          <div className="notice-box" style={{ marginTop: 14 }}>
            <Lock size={13} /> All documents are encrypted at rest (AWS S3 server-side encryption) and in transit
            (HTTPS/TLS). AI responses only ever draw on documents you're authorised to see.
          </div>
        </div>

        <div className="panel">
          <div className="panel-head">
            <span>
              <ScrollText size={14} style={{ marginRight: 6, verticalAlign: -2 }} />
              Audit log
            </span>
          </div>
          {AUDIT_LOG.map((a, i) => (
            <div className="audit-row" key={i}>
              <div className="audit-time">{a.time}</div>
              <div>
                <span className="audit-actor">{a.actor}</span> · {a.action}
                <div className="audit-detail">{a.detail}</div>
              </div>
            </div>
          ))}
          <div className="empty" style={{ marginTop: 4 }}>
            Immutable log, retained per Eduvos data retention policy · exportable for POPIA data subject requests
          </div>
        </div>
      </div>
    </div>
  );
}

function UploadModal({ onClose, onSubmit }) {
  const [title, setTitle] = useState("");
  const [type, setType] = useState("Fee Statement");
  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-head">
          <span>Upload a document</span>
          <button className="icon-btn ghost" onClick={onClose}>
            <X size={16} />
          </button>
        </div>
        <div className="dropzone">
          <UploadCloud size={22} />
          <div>Drag a file here, or click to browse</div>
          <div className="dropzone-sub">PDF, DOCX or a photo of a scanned letter</div>
        </div>
        <div className="login-field">
          <label>Document name</label>
          <input placeholder="e.g. NSFAS Appeal Letter" value={title} onChange={(e) => setTitle(e.target.value)} />
        </div>
        <div className="login-field">
          <label>Type</label>
          <select value={type} onChange={(e) => setType(e.target.value)}>
            {Object.keys(TYPE_STYLE).map((t) => (
              <option key={t}>{t}</option>
            ))}
          </select>
        </div>
        <button
          className="btn-primary full"
          onClick={() => {
            onSubmit(title || "Untitled document", type);
            onClose();
          }}
        >
          Upload securely
        </button>
        <div className="login-foot">
          Your file goes straight to encrypted storage via a one-time upload link — the app never handles it directly.
        </div>
      </div>
    </div>
  );
}

const NAV = [
  { key: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { key: "documents", label: "Documents", icon: FileText },
  { key: "ask", label: "Ask AI", icon: MessageSquareText },
  { key: "deadlines", label: "Deadlines", icon: Clock },
  { key: "security", label: "Security", icon: ShieldCheck },
];

export default function App() {
  const [loggedIn, setLoggedIn] = useState(false);
  const [screen, setScreen] = useState("dashboard");
  const [platform, setPlatform] = useState("web");
  const [docs, setDocs] = useState(SEED_DOCS);
  const [selectedDoc, setSelectedDoc] = useState(null);
  const [showUpload, setShowUpload] = useState(false);
  const [toast, setToast] = useState("");
  const name = "Londiwe Mahlangu";

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(""), 3200);
    return () => clearTimeout(t);
  }, [toast]);

  function goto(key) {
    setScreen(key);
  }

  function openDoc(doc) {
    setSelectedDoc(doc);
    setScreen("doc-detail");
  }

  function handleUpload(title, type) {
    const id = Math.max(...docs.map((d) => d.id)) + 1;
    const newDoc = { id, title, type, date: "25 Jul 2026", pages: 1, status: "Processing", confidence: 0, summary: "", entities: [] };
    setDocs((d) => [newDoc, ...d]);
    setToast("Document uploaded — extracting text and running AI analysis…");
    setTimeout(() => {
      setDocs((cur) =>
        cur.map((d) =>
          d.id === id
            ? {
                ...d,
                status: "Ready",
                confidence: 90,
                summary:
                  "AI analysis complete. This document has been classified as a " +
                  type +
                  " and its key dates and conditions have been extracted below.",
                entities: [{ label: "Detected type", value: type }],
              }
            : d
        )
      );
      setToast("AI analysis complete for \u201c" + title + "\u201d");
    }, 2600);
  }

  const isMobile = platform === "mobile";

  const body = !loggedIn ? (
    <LoginScreen
      onLogin={() => {
        setLoggedIn(true);
        setToast("Signed in securely");
      }}
    />
  ) : (
    <>
      {screen === "dashboard" && <Dashboard docs={docs} onOpen={openDoc} goto={goto} name={name} />}
      {screen === "documents" && <DocumentsScreen docs={docs} onOpen={openDoc} onUploadClick={() => setShowUpload(true)} />}
      {screen === "doc-detail" && <DocDetailScreen doc={selectedDoc} back={() => setScreen("documents")} goto={goto} />}
      {screen === "ask" && <AskScreen />}
      {screen === "deadlines" && <DeadlinesScreen />}
      {screen === "security" && <SecurityScreen />}
    </>
  );

  return (
    <div className="app-root">
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,600;9..144,700&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@500&display=swap');

        .app-root, .app-root * { box-sizing: border-box; }
        .app-root {
          --ink:#101A2B; --ink2:#1B2A44; --paper:#F7F6F1; --card:#FFFFFF;
          --teal:#0E7C74; --teal-light:#E4F2F0; --amber:#C97A2B; --amber-light:#FBEEE0;
          --slate:#5B6472; --line:#E4E1D8; --danger:#B3432D; --success:#2F855A;
          font-family: 'Inter', ui-sans-serif, system-ui, sans-serif;
          color: var(--ink);
          background: var(--paper);
          min-height: 100vh;
          display: flex;
          justify-content: center;
          padding: ${isMobile ? "24px 0" : "0"};
        }
        h1 { font-family:'Fraunces', ui-serif, Georgia, serif; font-weight:600; font-size: 26px; margin: 4px 0 2px; letter-spacing:-0.01em; }
        .eyebrow { font-size:11px; text-transform:uppercase; letter-spacing:0.08em; color:var(--teal); font-weight:600; }
        .sub { color: var(--slate); font-size: 13.5px; margin: 4px 0 0; max-width: 520px; }

        .shell { display:flex; width:100%; max-width:1180px; min-height:100vh; background:var(--paper); }
        .shell.mobile { max-width: 390px; min-height: auto; height: 800px; border:10px solid var(--ink); border-radius:38px; overflow:hidden; box-shadow: 0 30px 60px rgba(16,26,43,0.25); position:relative; }

        .sidebar { width:220px; background:var(--ink); color:#fff; display:flex; flex-direction:column; padding:20px 14px; flex-shrink:0; }
        .brand-row { display:flex; align-items:center; gap:9px; padding:6px 8px 22px; }
        .brand-mark { width:30px; height:30px; border-radius:9px; background:var(--teal); display:flex; align-items:center; justify-content:center; color:#fff; flex-shrink:0; }
        .brand-name { font-family:'Fraunces', serif; font-weight:600; font-size:17px; color:#fff; }
        .brand-sub { font-size:10.5px; color:#9AA7BD; max-width:150px; line-height:1.3; }

        .nav-item { display:flex; align-items:center; gap:10px; padding:10px 12px; border-radius:10px; color:#B7C0D1; font-size:13.5px; font-weight:500; cursor:pointer; border:none; background:transparent; width:100%; text-align:left; margin-bottom:2px; }
        .nav-item:hover { background: rgba(255,255,255,0.06); color:#fff; }
        .nav-item.active { background: var(--teal); color:#fff; }
        .sidebar-foot { margin-top:auto; padding-top:14px; border-top:1px solid rgba(255,255,255,0.12); }
        .user-chip { display:flex; align-items:center; gap:9px; padding:8px; }
        .avatar { width:30px; height:30px; border-radius:50%; background:var(--amber); color:#fff; display:flex; align-items:center; justify-content:center; font-size:11.5px; font-weight:700; flex-shrink:0; }
        .user-name { font-size:12.5px; color:#fff; font-weight:600; }
        .user-role { font-size:10.5px; color:#8D9AB0; }

        .main { flex:1; display:flex; flex-direction:column; min-width:0; }
        .topbar { display:flex; align-items:center; justify-content:space-between; padding:14px 28px; border-bottom:1px solid var(--line); background:var(--card); }
        .search-box { display:flex; align-items:center; gap:8px; background:var(--paper); border:1px solid var(--line); border-radius:9px; padding:7px 12px; font-size:13px; color:var(--slate); width:280px; }
        .search-box input { border:none; background:none; outline:none; font-size:13px; width:100%; color:var(--ink); }
        .top-actions { display:flex; align-items:center; gap:14px; }
        .platform-switch { display:flex; background:var(--paper); border:1px solid var(--line); border-radius:9px; padding:2px; }
        .platform-switch button { border:none; background:none; padding:6px 9px; border-radius:7px; font-size:11.5px; color:var(--slate); display:flex; align-items:center; gap:5px; cursor:pointer; font-weight:600; }
        .platform-switch button.active { background:var(--ink); color:#fff; }
        .bell-btn { position:relative; background:none; border:1px solid var(--line); border-radius:9px; padding:8px; cursor:pointer; color:var(--ink); }
        .bell-dot { position:absolute; top:6px; right:6px; width:6px; height:6px; border-radius:50%; background:var(--amber); }

        .content { flex:1; overflow-y:auto; padding: ${isMobile ? "16px" : "26px 28px 40px"}; }
        .screen-head { margin-bottom: 18px; }
        .screen-head.row { display:flex; align-items:flex-end; justify-content:space-between; gap:16px; flex-wrap:wrap; }

        .stat-grid { display:grid; grid-template-columns: repeat(${isMobile ? 2 : 4}, 1fr); gap:12px; margin-bottom:20px; }
        .stat-card { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:14px; display:flex; align-items:center; gap:10px; }
        .stat-icon { width:34px; height:34px; border-radius:9px; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
        .stat-value { font-family:'Fraunces', serif; font-size:19px; font-weight:600; line-height:1; }
        .stat-label { font-size:11px; color:var(--slate); margin-top:3px; }

        .two-col { display:grid; grid-template-columns: ${isMobile ? "1fr" : "1.1fr 1fr"}; gap:16px; align-items:start; }
        .panel { background:var(--card); border:1px solid var(--line); border-radius:16px; padding:18px; }
        .panel-head { display:flex; align-items:center; justify-content:space-between; font-size:13px; font-weight:600; margin-bottom:12px; color:var(--ink2); }
        .link { background:none; border:none; color:var(--teal); font-size:12px; font-weight:600; cursor:pointer; }
        .confidence { font-size:11px; color:var(--slate); font-weight:500; }

        .deadline-row { display:flex; align-items:center; gap:11px; padding:10px 0; border-bottom:1px solid var(--line); }
        .deadline-row:last-child { border-bottom:none; }
        .sev-dot { width:8px; height:8px; border-radius:50%; flex-shrink:0; }
        .sev-high { background:var(--danger); } .sev-medium { background:var(--amber); } .sev-low { background:var(--success); }
        .deadline-info { flex:1; min-width:0; }
        .deadline-action { font-size:13px; font-weight:600; }
        .deadline-doc { font-size:11.5px; color:var(--slate); }
        .deadline-due { text-align:right; font-size:12px; font-weight:600; flex-shrink:0; }
        .deadline-days { font-size:10.5px; color:var(--slate); font-weight:500; }

        .ask-teaser { display:flex; align-items:center; gap:12px; background:var(--teal-light); border-radius:12px; padding:13px; cursor:pointer; border:1px solid transparent; }
        .ask-teaser:hover { border-color:var(--teal); }
        .ask-teaser-icon { width:32px; height:32px; border-radius:9px; background:var(--teal); color:#fff; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
        .ask-teaser-title { font-size:13px; font-weight:600; }
        .ask-teaser-sub { font-size:11.5px; color:var(--slate); margin-top:2px; }

        .doc-list-mini { display:flex; flex-direction:column; gap:9px; margin-top:8px; }
        .doc-list { display:flex; flex-direction:column; gap:10px; }
        .doc-card { display:flex; align-items:center; gap:12px; background:var(--card); border:1px solid var(--line); border-radius:14px; padding:0; cursor:pointer; text-align:left; width:100%; overflow:hidden; }
        .doc-card:hover { border-color: var(--teal); }
        .doc-tab { width:6px; align-self:stretch; flex-shrink:0; }
        .doc-card-body { flex:1; min-width:0; padding:12px 6px; }
        .doc-card-top { display:flex; align-items:center; justify-content:space-between; margin-bottom:6px; }
        .tag { font-size:10px; font-weight:700; padding:3px 8px; border-radius:999px; text-transform:uppercase; letter-spacing:0.04em; }
        .ready-pill { font-size:10px; color:var(--success); font-weight:600; }
        .proc-pill { font-size:10px; color:var(--amber); font-weight:600; display:flex; align-items:center; gap:4px; }
        .doc-title { font-size:13.5px; font-weight:600; }
        .doc-meta { font-size:11px; color:var(--slate); margin-top:2px; }
        .doc-summary-preview { font-size:11.5px; color:var(--slate); margin-top:6px; display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden; line-height:1.4; }
        .doc-chevron { color:var(--slate); margin-right:12px; flex-shrink:0; }

        .filter-row { display:flex; gap:8px; flex-wrap:wrap; margin-bottom:16px; }
        .chip-filter { border:1px solid var(--line); background:var(--card); padding:6px 12px; border-radius:999px; font-size:12px; font-weight:600; color:var(--slate); cursor:pointer; }
        .chip-filter.active { background:var(--ink); color:#fff; border-color:var(--ink); }
        .empty { font-size:12.5px; color:var(--slate); padding:14px 0; text-align:center; }

        .back-link { display:flex; align-items:center; gap:6px; background:none; border:none; color:var(--slate); font-size:12.5px; font-weight:600; cursor:pointer; margin-bottom:14px; padding:0; }
        .detail-head { display:flex; gap:12px; margin-bottom:18px; }
        .detail-tab { width:6px; border-radius:4px; align-self:stretch; }
        .summary-text { font-size:13.5px; line-height:1.6; color:var(--ink2); }
        .entity-grid { display:grid; grid-template-columns: 1fr 1fr; gap:10px; }
        .entity { background:var(--paper); border-radius:10px; padding:10px 12px; }
        .entity-label { font-size:10.5px; color:var(--slate); font-weight:600; text-transform:uppercase; letter-spacing:0.03em; }
        .entity-value { font-family:'JetBrains Mono', monospace; font-size:13px; margin-top:3px; font-weight:500; }

        .doc-preview-page { background:var(--paper); border-radius:10px; padding:18px; border:1px solid var(--line); }
        .fake-line { height:7px; background:#DEDCD2; border-radius:4px; margin-bottom:8px; }
        .w-70{width:70%;} .w-90{width:90%;} .w-60{width:60%;} .w-80{width:80%;} .w-95{width:95%;} .w-40{width:40%;}
        .doc-preview-actions { display:flex; gap:8px; margin-top:10px; }
        .icon-btn { display:flex; align-items:center; gap:6px; border:1px solid var(--line); background:var(--card); padding:7px 11px; border-radius:9px; font-size:12px; font-weight:600; cursor:pointer; color:var(--ink); }
        .icon-btn.ghost { border:none; color:var(--slate); padding:4px; }
        .notice-box { display:flex; align-items:flex-start; gap:8px; background:var(--teal-light); color:#0B5A54; font-size:11.5px; padding:10px 12px; border-radius:10px; margin-top:12px; line-height:1.4; }

        .btn-primary { display:flex; align-items:center; justify-content:center; gap:7px; background:var(--teal); color:#fff; border:none; padding:10px 16px; border-radius:10px; font-size:13px; font-weight:600; cursor:pointer; white-space:nowrap; }
        .btn-primary:hover { background:#0B655E; }
        .btn-secondary { display:flex; align-items:center; justify-content:center; gap:7px; background:var(--paper); color:var(--ink); border:1px solid var(--line); padding:10px 16px; border-radius:10px; font-size:13px; font-weight:600; cursor:pointer; }
        .full { width:100%; }

        .chat-screen { display:flex; flex-direction:column; height: 100%; }
        .chat-window { flex:1; display:flex; flex-direction:column; background:var(--card); border:1px solid var(--line); border-radius:16px; overflow:hidden; min-height:${isMobile ? "420px" : "480px"}; }
        .chat-log { flex:1; overflow-y:auto; padding:18px; display:flex; flex-direction:column; gap:14px; }
        .bubble-row { display:flex; gap:9px; max-width:88%; }
        .bubble-row.from-user { align-self:flex-end; flex-direction:row-reverse; }
        .bubble-avatar { width:24px; height:24px; border-radius:50%; background:var(--teal); color:#fff; display:flex; align-items:center; justify-content:center; flex-shrink:0; margin-top:2px; }
        .bubble { background:var(--paper); border-radius:14px; padding:11px 14px; font-size:13.5px; line-height:1.5; }
        .from-user .bubble { background:var(--ink); color:#fff; }
        .bubble.typing { display:flex; align-items:center; gap:7px; color:var(--slate); }
        .source-chips { display:flex; flex-direction:column; gap:5px; margin-top:9px; }
        .source-chip { display:flex; align-items:center; gap:6px; font-size:11px; background:var(--teal-light); color:#0B5A54; padding:5px 9px; border-radius:8px; font-weight:600; }
        .suggestion-row { display:flex; gap:8px; padding:0 18px 12px; flex-wrap:wrap; }
        .suggestion-chip { border:1px solid var(--line); background:var(--card); padding:6px 11px; border-radius:999px; font-size:11.5px; color:var(--ink2); cursor:pointer; font-weight:500; }
        .chat-input-row { display:flex; gap:8px; padding:14px; border-top:1px solid var(--line); }
        .chat-input-row input { flex:1; border:1px solid var(--line); border-radius:10px; padding:10px 13px; font-size:13px; outline:none; }
        .chat-input-row .btn-primary { padding:10px 14px; }

        .timeline { position:relative; padding-left:6px; }
        .timeline-item { display:flex; gap:14px; position:relative; padding-bottom:20px; }
        .timeline-dot { width:12px; height:12px; border-radius:50%; margin-top:4px; flex-shrink:0; z-index:1; }
        .timeline-line { position:absolute; left:5px; top:16px; bottom:-4px; width:2px; background:var(--line); }
        .timeline-card { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:12px 14px; flex:1; }
        .timeline-top { display:flex; justify-content:space-between; align-items:center; margin-bottom:5px; }
        .timeline-due { font-size:12px; font-weight:700; }
        .sev-pill { font-size:10px; font-weight:700; padding:3px 8px; border-radius:999px; }
        .sev-pill.sev-high { background:#FBE7E2; color:var(--danger); }
        .sev-pill.sev-medium { background:var(--amber-light); color:var(--amber); }
        .sev-pill.sev-low { background:#E3F1E8; color:var(--success); }
        .timeline-action { font-size:13.5px; font-weight:600; margin-bottom:3px; }
        .timeline-doc { display:flex; align-items:center; gap:5px; font-size:11.5px; color:var(--slate); }

        .setting-row { display:flex; align-items:center; justify-content:space-between; gap:12px; padding:12px 0; border-bottom:1px solid var(--line); }
        .setting-row:last-of-type { border-bottom:none; }
        .setting-title { display:flex; align-items:center; gap:7px; font-size:13px; font-weight:600; }
        .setting-sub { font-size:11.5px; color:var(--slate); margin-top:2px; margin-left:21px; }
        .toggle { width:38px; height:22px; border-radius:999px; background:#D8D5C9; border:none; cursor:pointer; padding:2px; flex-shrink:0; }
        .toggle.on { background:var(--teal); }
        .toggle-knob { display:block; width:18px; height:18px; border-radius:50%; background:#fff; transition:transform 0.15s ease; }
        .toggle.on .toggle-knob { transform:translateX(16px); }

        .audit-row { display:flex; gap:12px; padding:10px 0; border-bottom:1px solid var(--line); font-size:12.5px; }
        .audit-row:last-child { border-bottom:none; }
        .audit-time { font-family:'JetBrains Mono', monospace; font-size:10.5px; color:var(--slate); width:118px; flex-shrink:0; padding-top:1px; }
        .audit-actor { font-weight:700; }
        .audit-detail { color:var(--slate); font-size:11.5px; margin-top:1px; }

        .login-wrap { flex:1; display:flex; align-items:center; justify-content:center; padding:24px; min-height:100vh; }
        .login-card { background:var(--card); border:1px solid var(--line); border-radius:20px; padding:30px; width:100%; max-width:380px; }
        .login-brand { display:flex; align-items:center; gap:11px; margin-bottom:26px; }
        .login-field { margin-bottom:14px; }
        .login-field label { font-size:11.5px; font-weight:600; color:var(--ink2); display:block; margin-bottom:5px; }
        .login-field input, .login-field select { width:100%; border:1px solid var(--line); border-radius:9px; padding:10px 12px; font-size:13px; outline:none; background:var(--paper); }
        .login-mfa { display:flex; align-items:center; gap:6px; font-size:11px; color:var(--slate); background:var(--paper); border-radius:9px; padding:8px 10px; margin-bottom:16px; }
        .login-foot { font-size:11px; color:var(--slate); text-align:center; margin-top:14px; line-height:1.5; }

        .modal-backdrop { position:fixed; inset:0; background:rgba(16,26,43,0.45); display:flex; align-items:center; justify-content:center; z-index:50; padding:20px; }
        .modal { background:var(--card); border-radius:18px; padding:22px; width:100%; max-width:380px; }
        .modal-head { display:flex; align-items:center; justify-content:space-between; font-size:14px; font-weight:700; margin-bottom:14px; }
        .dropzone { border:1.5px dashed var(--line); border-radius:12px; padding:22px 14px; text-align:center; color:var(--slate); font-size:12.5px; margin-bottom:16px; display:flex; flex-direction:column; align-items:center; gap:6px; }
        .dropzone-sub { font-size:10.5px; }

        .toast { position:fixed; bottom:24px; left:50%; transform:translateX(-50%); background:var(--ink); color:#fff; padding:11px 18px; border-radius:12px; font-size:12.5px; display:flex; align-items:center; gap:8px; z-index:60; box-shadow:0 12px 30px rgba(16,26,43,0.3); }

        .spin { animation: spin 1s linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }

        .mobile-tabbar { display:flex; border-top:1px solid var(--line); background:var(--card); padding:8px 6px 10px; }
        .mobile-tab { flex:1; display:flex; flex-direction:column; align-items:center; gap:3px; background:none; border:none; color:var(--slate); font-size:9.5px; font-weight:600; cursor:pointer; padding:4px; }
        .mobile-tab.active { color:var(--teal); }

        @media (max-width: 720px) {
          .shell:not(.mobile) .sidebar { display:none; }
          .two-col { grid-template-columns: 1fr; }
          .stat-grid { grid-template-columns: repeat(2,1fr); }
        }
      `}</style>

      <div className={"shell" + (isMobile ? " mobile" : "")}>
        {loggedIn && !isMobile && (
          <div className="sidebar">
            <div className="brand-row">
              <div className="brand-mark">
                <FolderOpen size={16} />
              </div>
              <div>
                <div className="brand-name">Folio</div>
                <div className="brand-sub">Financial documents, understood</div>
              </div>
            </div>
            {NAV.map((n) => (
              <button key={n.key} className={"nav-item" + (screen === n.key || (screen === "doc-detail" && n.key === "documents") ? " active" : "")} onClick={() => goto(n.key)}>
                <n.icon size={16} /> {n.label}
              </button>
            ))}
            <div className="sidebar-foot">
              <div className="user-chip">
                <div className="avatar">{initials(name)}</div>
                <div>
                  <div className="user-name">{name}</div>
                  <div className="user-role">BSc Software Engineering</div>
                </div>
              </div>
              <button className="nav-item" onClick={() => setLoggedIn(false)}>
                <LogOut size={16} /> Sign out
              </button>
            </div>
          </div>
        )}

        <div className="main">
          {loggedIn && (
            <div className="topbar">
              {!isMobile ? (
                <div className="search-box">
                  <Search size={14} />
                  <input placeholder="Search your documents…" />
                </div>
              ) : (
                <div className="brand-row" style={{ padding: 0 }}>
                  <div className="brand-mark">
                    <FolderOpen size={15} />
                  </div>
                  <div className="brand-name" style={{ color: "var(--ink)", fontSize: 15 }}>
                    Folio
                  </div>
                </div>
              )}
              <div className="top-actions">
                <div className="platform-switch">
                  <button className={!isMobile ? "active" : ""} onClick={() => setPlatform("web")}>
                    <Monitor size={12} /> Web
                  </button>
                  <button className={isMobile ? "active" : ""} onClick={() => setPlatform("mobile")}>
                    <Smartphone size={12} /> Mobile
                  </button>
                </div>
                <button className="bell-btn">
                  <Bell size={16} />
                  <span className="bell-dot" />
                </button>
                {isMobile && (
                  <div className="avatar" style={{ width: 26, height: 26, fontSize: 10 }}>
                    {initials(name)}
                  </div>
                )}
              </div>
            </div>
          )}

          <div className="content">{body}</div>

          {loggedIn && isMobile && (
            <div className="mobile-tabbar">
              {NAV.map((n) => (
                <button key={n.key} className={"mobile-tab" + (screen === n.key ? " active" : "")} onClick={() => goto(n.key)}>
                  <n.icon size={17} />
                  {n.label}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {showUpload && <UploadModal onClose={() => setShowUpload(false)} onSubmit={handleUpload} />}
      <Toast text={toast} />
    </div>
  );
}
