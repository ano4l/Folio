"use client";

import { useEffect, useState, type FormEvent } from "react";
import { AlertCircle, ArrowLeft, ArrowRight, FolderOpen, Sparkles } from "lucide-react";
import { createAdminDemoData, DEMO_ADMIN_EMAIL, DEMO_ADMIN_PASSWORD, DEMO_ADMIN_USER, type AdminDemoData } from "../../../lib/admin-demo";
import AdminPage from "./AdminPage";

// A presentation preference only. This never creates a Folio authentication cookie.
const DEMO_STORAGE_KEY = "folio-admin-demo-open";

export default function AdminDemo() {
  const [data, setData] = useState<AdminDemoData | null>(null);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    try {
      if (sessionStorage.getItem(DEMO_STORAGE_KEY) === "true") setData(createAdminDemoData());
    } catch { /* The demo also works when browser storage is unavailable. */ }
  }, []);

  function signIn(event: FormEvent) {
    event.preventDefault();
    if (email.trim().toLowerCase() !== DEMO_ADMIN_EMAIL || password !== DEMO_ADMIN_PASSWORD) {
      setError("Use the demo email and password shown below.");
      return;
    }
    try { sessionStorage.setItem(DEMO_STORAGE_KEY, "true"); } catch { /* Optional persistence. */ }
    setError("");
    setPassword("");
    setData(createAdminDemoData());
  }

  async function exitDemo() {
    try { sessionStorage.removeItem(DEMO_STORAGE_KEY); } catch { /* Optional persistence. */ }
    setData(null);
    setEmail("");
    setPassword("");
    setError("");
  }

  if (data) return <AdminPage user={DEMO_ADMIN_USER} logout={exitDemo} demoData={data} />;

  return <main className="login-page">
    <div className="login-card fa-demo-login">
      <div className="brand"><span><FolderOpen size={19} /></span><div><b>Folio</b><small>Administration demo</small></div></div>
      <span className="fa-demo-tag"><Sparkles size={13} />Fictional sample data</span>
      <h1>Explore the admin side.</h1>
      <p>Try the dashboard with sample student accounts, sign-in sessions and AI activity.</p>
      <form className="login-form" onSubmit={signIn}>
        <label>Demo email<input type="email" autoComplete="off" required value={email} onChange={(event) => setEmail(event.target.value)} placeholder={DEMO_ADMIN_EMAIL} /></label>
        <label>Demo password<input type="password" autoComplete="off" required value={password} onChange={(event) => setPassword(event.target.value)} aria-describedby="fa-demo-credentials" /></label>
        {error && <div className="mfa-error-message" role="alert"><AlertCircle size={14} /><span>{error}</span></div>}
        <button type="submit" className="primary full">Open admin demo<ArrowRight size={15} /></button>
      </form>
      <div className="fa-demo-credentials" id="fa-demo-credentials">
        <strong>Demo login details</strong>
        <dl><div><dt>Email</dt><dd>{DEMO_ADMIN_EMAIL}</dd></div><div><dt>Password</dt><dd>{DEMO_ADMIN_PASSWORD}</dd></div></dl>
        <button type="button" className="secondary full" onClick={() => { setEmail(DEMO_ADMIN_EMAIL); setPassword(DEMO_ADMIN_PASSWORD); setError(""); }}>Use demo details</button>
      </div>
      <small className="login-foot">This demo uses fictional records. No email code is needed.</small>
      <a className="fa-demo-link" href="/admin"><ArrowLeft size={14} />Go to real admin sign-in</a>
    </div>
  </main>;
}
