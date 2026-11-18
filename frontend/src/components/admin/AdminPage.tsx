"use client";

import { useEffect, useState, type FormEvent } from "react";
import { ArrowLeft, ArrowRight, Check, ChevronLeft, ChevronRight, Clock3, FolderOpen, LogOut, RefreshCw, Search, ShieldCheck, Sparkles, Users, X } from "lucide-react";
import type { AdminOverview, AdminPageData, AdminSession, AdminUsage, AdminUser } from "../../../lib/admin-types";
import { readAdminDemo, type AdminDemoData } from "../../../lib/admin-demo";
import { API_URL } from "../workspace/api";
import type { User } from "../workspace/models";
import { ErrorNotice, PageHeader } from "../workspace/ui";

type View = "users" | "sessions" | "usage";
type Row = AdminUser | AdminSession | AdminUsage;
type AccountFilter = { id: string; displayName: string; email: string };
const views = [ ["users", "Users", Users], ["sessions", "Sessions", Clock3], ["usage", "AI usage", Sparkles] ] as const;
const titles = { users: "All accounts", sessions: "Session history", usage: "Recorded AI usage" };
const number = (value: number) => value.toLocaleString("en-ZA");
function date(value: string | null) {
  if (!value) return "—";
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? "Unavailable" : parsed.toLocaleString("en-ZA", { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

class AdminRequestError extends Error {
  constructor(message: string, public status: number) { super(message); }
}

async function getAdmin<T>(query: URLSearchParams, signal: AbortSignal, demoData?: AdminDemoData): Promise<T> {
  signal.throwIfAborted();
  if (demoData) return readAdminDemo(demoData, query) as T;
  const response = await fetch(`${API_URL}/v1/admin?${query}`, { credentials: "include", cache: "no-store", signal });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new AdminRequestError(body.message || "Administration is temporarily unavailable.", response.status);
  return body as T;
}

export default function AdminPage({ user, logout, demoData }: { user: User; logout: () => Promise<void>; demoData?: AdminDemoData }) {
  const [view, setView] = useState<View>("users");
  const [searchInput, setSearchInput] = useState("");
  const [search, setSearch] = useState("");
  const [days, setDays] = useState("30");
  const [account, setAccount] = useState<AccountFilter | null>(null);
  const [page, setPage] = useState(1);
  const [refresh, setRefresh] = useState(0);
  const [overview, setOverview] = useState<AdminOverview | null>(null);
  const [result, setResult] = useState<AdminPageData<Row> | null>(null);
  const [overviewLoading, setOverviewLoading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [overviewError, setOverviewError] = useState("");
  const [error, setError] = useState("");
  const [accessError, setAccessError] = useState("");

  useEffect(() => {
    if (!user.isAdmin || accessError) return;
    const controller = new AbortController();
    setOverview(null);
    setOverviewError("");
    setOverviewLoading(true);
    getAdmin<AdminOverview>(new URLSearchParams({ view: "overview" }), controller.signal, demoData)
      .then((data) => { if (!controller.signal.aborted) setOverview(data); })
      .catch((problem: unknown) => {
        if (controller.signal.aborted) return;
        setOverview(null);
        if (problem instanceof AdminRequestError && [401, 403].includes(problem.status)) {
          setResult(null);
          setAccessError(problem.status === 401 ? "Your session has ended. Sign in again to continue." : "This account no longer has administrator access.");
        } else setOverviewError(problem instanceof Error ? problem.message : "Unable to load the overview.");
      }).finally(() => { if (!controller.signal.aborted) setOverviewLoading(false); });
    return () => controller.abort();
  }, [user.isAdmin, refresh, accessError, demoData]);

  useEffect(() => {
    if (!user.isAdmin || accessError) return;
    const controller = new AbortController();
    const query = new URLSearchParams({ view, page: String(page), pageSize: "25" });
    if (view === "users" && search) query.set("search", search);
    if (view !== "users") {
      query.set("days", days);
      if (account) query.set("userId", account.id);
    }
    setResult(null);
    setError("");
    setLoading(true);
    getAdmin<AdminPageData<Row>>(query, controller.signal, demoData)
      .then((data) => {
        if (controller.signal.aborted) return;
        const lastPage = Math.max(1, Math.ceil(data.total / data.pageSize));
        if (page > lastPage) {
          setPage(lastPage);
          return;
        }
        setResult(data);
      })
      .catch((problem: unknown) => {
        if (controller.signal.aborted) return;
        setResult(null);
        if (problem instanceof AdminRequestError && [401, 403].includes(problem.status)) {
          setOverview(null);
          setAccessError(problem.status === 401 ? "Your session has ended. Sign in again to continue." : "This account no longer has administrator access.");
        } else setError(problem instanceof Error ? problem.message : "Unable to load these records.");
      }).finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [user.isAdmin, view, page, search, days, account, refresh, accessError, demoData]);

  function changeView(next: View) {
    if (next === view) return;
    setView(next); setPage(1); setResult(null); setError("");
  }
  function inspect(selected: AdminUser, next: View) {
    setAccount({ id: selected.id, displayName: selected.displayName, email: selected.email });
    setPage(1);
    setResult(null);
    changeView(next);
  }
  function submitSearch(event: FormEvent) {
    event.preventDefault();
    const cleaned = searchInput.trim();
    setSearch(cleaned); setPage(1); setResult(null); setError(""); setRefresh((current) => current + 1);
  }

  if (!user.isAdmin || accessError) return <main className="ws-shell folio-admin"><div className="fa-denied">
    <ShieldCheck size={32} /><span className="fa-eyebrow">Folio administration</span>
    <h1>{accessError ? "Access unavailable" : "Administrator access required"}</h1>
    <p>{accessError || "This account does not have permission to view administration."}</p>
    <div className="ws-actions"><a className="secondary" href="/"><ArrowLeft size={16} />Back to workspace</a><button className="primary" onClick={() => void logout()}>Sign in with another account</button></div>
    <a className="fa-demo-link" href="/admin/demo">Explore the admin demo with sample data<ArrowRight size={14} /></a>
  </div></main>;

  const pages = result ? Math.max(1, Math.ceil(result.total / result.pageSize)) : 1;
  const emptyText = view === "users" ? (search ? "No accounts match your search." : "No accounts available.") : `No ${view === "sessions" ? "sessions" : "AI records"} in this period${account ? " for this account" : ""}.`;

  return <main className="ws-shell folio-admin">
    <aside className="ws-sidebar fa-sidebar">
      <a href="/" className="ws-brand"><span><FolderOpen size={22} /></span><b>Folio<small>Administration</small></b></a>
      <span className="fa-nav-label">Manage</span>
      <nav aria-label="Administration navigation">{views.map(([key, label, Icon]) => <button key={key} className={view === key ? "active" : ""} aria-current={view === key ? "page" : undefined} onClick={() => changeView(key)}><Icon size={18} /><span>{label}</span></button>)}</nav>
      <a href="/" className="ws-admin-link fa-back"><ArrowLeft size={16} />Back to workspace</a>
      <div className="ws-sidebar-bottom"><div className="ws-account"><span>{user.displayName.slice(0, 2).toUpperCase()}</span><div><b>{user.displayName}</b><small>{user.email}</small></div></div><button className="ws-signout" onClick={() => void logout()}><LogOut size={17} />{demoData ? "Exit demo" : "Sign out"}</button></div>
    </aside>
    <div className="ws-main">
      <header className="ws-topbar fa-topbar"><a href="/" className="fa-mobile-home"><FolderOpen size={22} /><b>Folio</b></a><span className="fa-topbar-title"><ShieldCheck size={16} />{demoData ? "Demo administrator workspace" : "Administrator workspace"}</span><a className="fa-workspace-return" href="/"><ArrowLeft size={14} />Workspace</a><button className="secondary fa-mobile-signout" onClick={() => void logout()}><LogOut size={15} />{demoData ? "Exit demo" : "Sign out"}</button></header>
      <div className="ws-content fa-content">
        <PageHeader title="Administration" subtitle="A clear view of accounts, sessions and recorded AI activity.">{!demoData && <a className="secondary" href="/admin/demo">View demo</a>}<button className="secondary" onClick={() => { setOverview(null); setResult(null); setRefresh((current) => current + 1); }} disabled={loading || overviewLoading}><RefreshCw size={15} className={loading || overviewLoading ? "spin" : ""} />Refresh</button></PageHeader>
        {demoData && <div className="fa-demo-banner" role="note"><Sparkles size={19} /><p><strong>Demo mode · fictional data</strong><span>Explore sample users, sessions and AI activity. These records are for demonstration only.</span></p><a href="/admin">Real admin sign-in<ArrowRight size={14} /></a></div>}
        {!demoData && <div className="fa-privacy"><ShieldCheck size={18} /><p><strong>Account insights. Private documents stay private.</strong><span>This page shows account details and activity metadata. It does not provide access to documents, prompts or AI answers.</span></p></div>}
        <section className="fa-overview" aria-label="Global account overview" aria-busy={overviewLoading}>
          <div className="fa-overview-label"><span className="fa-eyebrow">{demoData ? "Across the demo" : "Across Folio"}</span><span>{demoData ? "Sample totals · fictional accounts" : "Global totals · all accounts"}</span></div>
          <dl className="fa-metrics">
            <div><dt><Users size={16} />Accounts</dt><dd>{overview ? number(overview.totalUsers) : "—"}</dd><p>{overview ? `${number(overview.verifiedUsers)} verified` : overviewLoading ? "Loading overview…" : "Overview unavailable"}</p></div>
            <div><dt><ShieldCheck size={16} />Active sessions</dt><dd>{overview ? number(overview.activeSessions) : "—"}</dd><p>Unexpired and not revoked</p></div>
            <div><dt><Clock3 size={16} />Sessions · 30 days</dt><dd>{overview ? number(overview.sessionsLast30Days) : "—"}</dd><p>Sessions created</p></div>
            <div><dt><Sparkles size={16} />Recorded AI requests</dt><dd>{overview ? number(overview.recordedAiRequests) : "—"}</dd><p>{overview ? `${number(overview.aiRequestsLast30Days)} in the last 30 days` : "Ask AI and study quizzes"}</p></div>
          </dl><ErrorNotice message={overviewError} />
        </section>
        <section className="fa-records" aria-label="Administration records">
          <div className="fa-tabs" role="tablist" aria-label="Record type">{views.map(([key, label, Icon]) => <button key={key} id={`fa-tab-${key}`} role="tab" aria-selected={view === key} aria-controls="fa-record-panel" tabIndex={view === key ? 0 : -1} className={view === key ? "active" : ""} onClick={() => changeView(key)} onKeyDown={(event) => { if (["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) { event.preventDefault(); const index = views.findIndex((entry) => entry[0] === view); const next = event.key === "Home" ? 0 : event.key === "End" ? views.length - 1 : (index + (event.key === "ArrowRight" ? 1 : -1) + views.length) % views.length; changeView(views[next][0]); document.getElementById(`fa-tab-${views[next][0]}`)?.focus(); } }}><Icon size={16} />{label}</button>)}</div>
          <div role="tabpanel" id="fa-record-panel" aria-labelledby={`fa-tab-${view}`}>
            <div className="fa-record-heading"><div><h2>{titles[view]}</h2><p>{view === "users" ? "Registered users, including accounts awaiting verification." : view === "sessions" ? "Created, expired and revoked sessions. Active does not indicate online presence." : "Successful Ask AI answers and generated study quizzes recorded by Folio."}</p></div>{result && <span className="fa-record-count">{number(result.total)} {result.total === 1 ? "record" : "records"}</span>}</div>
            {view === "users" ? <form className="fa-filters" onSubmit={submitSearch}><label className="fa-search"><Search size={16} /><input aria-label="Search users by name or email" placeholder="Search name or email" maxLength={120} value={searchInput} onChange={(event) => setSearchInput(event.target.value)} /></label><button className="secondary" type="submit">Search</button>{(search || searchInput) && <button className="fa-clear" type="button" onClick={() => { setSearchInput(""); setSearch(""); setPage(1); setResult(null); setError(""); setRefresh((current) => current + 1); }}><X size={14} />Clear</button>}</form> : <div className="fa-filters"><label className="fa-period">Period<select value={days} onChange={(event) => { setDays(event.target.value); setPage(1); setResult(null); }}><option value="7">Last 7 days</option><option value="30">Last 30 days</option><option value="90">Last 90 days</option><option value="all">All time</option></select></label>{account ? <div className="fa-account-filter"><span><strong>{account.displayName}</strong><small>{account.email}</small></span><button className="ws-icon" aria-label="Clear account filter" onClick={() => { setAccount(null); setPage(1); setResult(null); }}><X size={16} /></button></div> : <span className="fa-filter-scope">All accounts</span>}</div>}
            {view === "usage" && <p className="fa-coverage"><Sparkles size={15} /><span>Coverage is limited to existing recorded answers and quizzes. Document summaries, failed or unrecorded provider calls, token counts and costs are not included.</span></p>}
            <ErrorNotice message={error} />
            {error && <button className="secondary fa-retry" onClick={() => setRefresh((current) => current + 1)}>Try again</button>}
            {loading && <div className="fa-empty" role="status"><RefreshCw size={22} className="spin" /><h3>Loading {view === "usage" ? "AI usage" : view}…</h3><p>Retrieving account metadata securely.</p></div>}
            {!loading && !error && result && result.items.length === 0 && <div className="fa-empty"><Search size={25} /><h3>{emptyText}</h3><p>{view === "users" && search ? "Try a different name or email address." : "Records will appear here when available."}</p></div>}
            {!loading && !error && !!result?.items.length && <p className="fa-scroll-hint"><ArrowRight size={14} />Swipe the table to see all columns</p>}
            {!loading && !error && result && result.items.length > 0 && <div className="fa-table-scroll" tabIndex={0} role="region" aria-label={`${titles[view]} table, scroll horizontally for more columns`}><table className="fa-table"><caption className="fa-sr-only">{titles[view]}{view !== "users" && account ? ` for ${account.displayName}` : ""}</caption><thead><tr>{(view === "users" ? ["Account", "Verification", "Joined", "Activity"] : view === "sessions" ? ["Account", "Created", "Expires", "Status", "Revoked"] : ["Account", "Recorded", "Model", "Grounded", "Abstained"]).map((label) => <th key={label} scope="col">{label}</th>)}</tr></thead><tbody>{result.items.map((row) => view === "users" ? (() => { const entry = row as AdminUser; return <tr key={entry.id}><td><Account user={entry} />{entry.isAdmin && <span className="fa-admin-label">Administrator</span>}</td><td><span className={`fa-badge ${entry.verified ? "positive" : "pending"}`}>{entry.verified && <Check size={12} />}{entry.verified ? "Verified" : "Unverified"}</span></td><td className="fa-date">{date(entry.createdAt)}</td><td><div className="fa-row-actions"><button onClick={() => inspect(entry, "sessions")} aria-label={`View sessions for ${entry.email}`}>Sessions<ArrowRight size={12} /></button><button onClick={() => inspect(entry, "usage")} aria-label={`View AI usage for ${entry.email}`}>AI usage<ArrowRight size={12} /></button></div></td></tr>; })() : view === "sessions" ? (() => { const entry = row as AdminSession; return <tr key={entry.id}><td><Account user={entry.user} /></td><td className="fa-date">{date(entry.createdAt)}</td><td className="fa-date">{date(entry.expiresAt)}</td><td><span className={`fa-badge ${entry.status === "Active" ? "positive" : "neutral"}`}>{entry.status}</span></td><td className="fa-date">{date(entry.revokedAt)}</td></tr>; })() : (() => { const entry = row as AdminUsage; return <tr key={entry.id}><td><Account user={entry.user} /></td><td className="fa-date">{date(entry.createdAt)}</td><td className="fa-model">{entry.model || "Not recorded"}</td><td>{entry.grounded ? "Yes" : "No"}</td><td>{entry.abstained ? "Yes" : "No"}</td></tr>; })())}</tbody></table></div>}
            {result && !loading && !error && result.total > 0 && <footer className="fa-pagination"><p>{number((result.page - 1) * result.pageSize + 1)}–{number(Math.min(result.page * result.pageSize, result.total))} of {number(result.total)}</p><div><button className="secondary" aria-label="Previous page" disabled={page <= 1} onClick={() => { setResult(null); setPage((current) => current - 1); }}><ChevronLeft size={16} /><span>Previous</span></button><span className="fa-page-number">{page} / {pages}</span><button className="secondary" aria-label="Next page" disabled={page >= pages} onClick={() => { setResult(null); setPage((current) => current + 1); }}><span>Next</span><ChevronRight size={16} /></button></div></footer>}
          </div>
        </section>
        <p className="fa-footer-note"><ShieldCheck size={13} />{demoData ? "Read-only demo · fictional records" : "Read-only administration"} · session timestamps shown in your browser’s timezone</p>
      </div>
    </div>
  </main>;
}

function Account({ user }: { user: { displayName: string; email: string } }) {
  return <div className="fa-account"><strong>{user.displayName || "Unnamed account"}</strong><span>{user.email}</span></div>;
}
