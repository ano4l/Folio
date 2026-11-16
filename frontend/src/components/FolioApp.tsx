"use client";
import { useEffect, useRef, useState } from "react";
import {
  startAuthentication,
  startRegistration,
  browserSupportsWebAuthn,
} from "@simplewebauthn/browser";
import {
  FolderOpen,
  AlertCircle,
  ShieldCheck,
  ArrowRight,
  ScanFace,
  Fingerprint,
  RotateCw,
} from "lucide-react";
import Workspace from "./workspace/Workspace";
import AdminPage from "./admin/AdminPage";
import type { User as AuthUser } from "./workspace/models";
import { API_URL } from "./workspace/api";

export default function FolioApp({ initialView = "workspace" }: { initialView?: "workspace" | "admin" }) {
  const [authStep, setAuthStep] = useState<
    "checking" | "credentials" | "mfa" | "authenticated"
  >("checking");
  const [authMode, setAuthMode] = useState<"login" | "register">("login");
  const [displayNameInput, setDisplayNameInput] = useState("");
  const [emailInput, setEmailInput] = useState("");
  const [passwordInput, setPasswordInput] = useState("");
  const [authUser, setAuthUser] = useState<AuthUser | null>(null);
  const [challengeId, setChallengeId] = useState("");
  const [authLoading, setAuthLoading] = useState(false);
  const [authError, setAuthError] = useState("");
  const [mfaDigits, setMfaDigits] = useState<string[]>([
    "",
    "",
    "",
    "",
    "",
    "",
  ]);
  const [mfaError, setMfaError] = useState("");
  const [mfaTimer, setMfaTimer] = useState(59);
  const [isResending, setIsResending] = useState(false);
  const [biometricScanning, setBiometricScanning] = useState(false);
  const [biometricDone, setBiometricDone] = useState(false);
  const [toast, setToast] = useState("");
  const [, setToastType] = useState("success");
  const mfaRefs = useRef<(HTMLInputElement | null)[]>([]);
  useEffect(() => {
    const controller = new AbortController();
    fetch(`${API_URL}/v1/auth/me`, {
      credentials: "include",
      signal: controller.signal,
    })
      .then(async (response) =>
        response.ok ? response.json() : Promise.reject(),
      )
      .then((user: AuthUser) => {
        setAuthUser(user);
        setAuthStep("authenticated");
      })
      .catch(() => {
        if (!controller.signal.aborted) setAuthStep("credentials");
      });
    return () => controller.abort();
  }, []);
  useEffect(() => {
    if (authStep !== "mfa" || mfaTimer <= 0) return;
    const timer = setInterval(() => setMfaTimer((value) => value - 1), 1000);
    return () => clearInterval(timer);
  }, [authStep, mfaTimer]);
  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => setToast(""), 6000);
      return () => clearTimeout(timer);
    }
  }, [toast]);

  const handleCredentialsSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setAuthLoading(true);
    setAuthError("");
    try {
      const payload =
        authMode === "register"
          ? {
              displayName: displayNameInput,
              email: emailInput,
              password: passwordInput,
            }
          : { email: emailInput, password: passwordInput };
      const response = await fetch(`${API_URL}/v1/auth/${authMode}`, {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
          "X-Requested-With": "FolioWeb",
        },
        body: JSON.stringify(payload),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data.message || "Unable to continue");
      setChallengeId(data.challengeId);
      setAuthStep("mfa");
      setMfaTimer(data.resendAfterSeconds || 60);
      setMfaError("");
      setMfaDigits(["", "", "", "", "", ""]);
      setToast(`Verification code sent to ${data.destination}.`);
    } catch (error) {
      setAuthError(
        error instanceof Error ? error.message : "Unable to continue",
      );
    } finally {
      setAuthLoading(false);
    }
  };

  const handleMfaChange = (index: number, val: string) => {
    // Paste and OTP autofill can supply several digits to a single field.
    const digits = val.replace(/\D/g, "");
    if (!digits) {
      const nextMfa = [...mfaDigits];
      nextMfa[index] = "";
      setMfaDigits(nextMfa);
      return;
    }
    const nextMfa = [...mfaDigits];
    digits
      .slice(0, 6 - index)
      .split("")
      .forEach((digit, offset) => {
        nextMfa[index + offset] = digit;
      });
    setMfaDigits(nextMfa);

    const nextIndex = Math.min(index + digits.length, 5);
    if (nextIndex < 5) {
      mfaRefs.current[nextIndex]?.focus();
    }
    if (nextMfa.join("").length === 6) {
      const code = nextMfa.join("");
      if (code.length === 6) {
        setTimeout(() => handleVerifyMfa(nextMfa), 150);
      }
    }
  };

  const handleMfaKeyDown = (
    index: number,
    e: React.KeyboardEvent<HTMLInputElement>,
  ) => {
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
      setMfaError(
        "Please fill out the full 6-digit verification security code.",
      );
      return;
    }
    setAuthLoading(true);
    setMfaError("");
    try {
      const response = await fetch(`${API_URL}/v1/auth/verify`, {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
          "X-Requested-With": "FolioWeb",
        },
        body: JSON.stringify({ challengeId, code }),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok)
        throw new Error(data.message || "Unable to verify this code");
      setAuthUser(data);
      setAuthStep("authenticated");
      setPasswordInput("");
      setToast(
        authMode === "register"
          ? "Account verified. Welcome to Folio."
          : "Identity verified. Welcome back.",
      );
    } catch (error) {
      setMfaError(
        error instanceof Error ? error.message : "Unable to verify this code",
      );
    } finally {
      setAuthLoading(false);
    }
  };

  const handleResendMfa = async () => {
    setIsResending(true);
    try {
      const response = await fetch(`${API_URL}/v1/auth/resend`, {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
          "X-Requested-With": "FolioWeb",
        },
        body: JSON.stringify({ challengeId }),
      });
      const data = await response.json().catch(() => ({}));
      if (!response.ok)
        throw new Error(data.message || "Unable to resend the code");
      setChallengeId(data.challengeId);
      setMfaTimer(data.resendAfterSeconds || 60);
      setMfaDigits(["", "", "", "", "", ""]);
      setMfaError("");
      setToast(`A fresh code was sent to ${data.destination}.`);
    } catch (error) {
      setMfaError(
        error instanceof Error ? error.message : "Unable to resend the code",
      );
    } finally {
      setIsResending(false);
    }
  };

  const handleLogout = async () => {
    await fetch(`${API_URL}/v1/auth/logout`, {
      method: "POST",
      credentials: "include",
      headers: { "X-Requested-With": "FolioWeb" },
    }).catch(() => undefined);
    setAuthUser(null);
    setAuthStep("credentials");
    setPasswordInput("");
  };

  const handleBiometricLogin = () => {
    void (async () => {
      if (!browserSupportsWebAuthn()) {
        setAuthError("Passkey sign-in is not supported in this browser.");
        return;
      }
      setBiometricScanning(true);
      setAuthError("");
      try {
        const optionsResponse = await fetch(`${API_URL}/v1/auth/passkey`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "FolioWeb",
          },
          body: JSON.stringify({ action: "login-options", email: emailInput }),
        });
        const options = await optionsResponse.json();
        if (!optionsResponse.ok)
          throw new Error(options.message || "Unable to start passkey sign-in");
        const assertion = await startAuthentication({
          optionsJSON: options.options,
        });
        const verifyResponse = await fetch(`${API_URL}/v1/auth/passkey`, {
          method: "POST",
          credentials: "include",
          headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "FolioWeb",
          },
          body: JSON.stringify({
            action: "login-verify",
            challengeId: options.challengeId,
            response: assertion,
          }),
        });
        const user = await verifyResponse.json();
        if (!verifyResponse.ok)
          throw new Error(user.message || "Passkey verification failed");
        setAuthUser(user);
        setAuthStep("authenticated");
        setBiometricDone(true);
        setToast("Passkey verified. Welcome back.");
      } catch (error) {
        setAuthError(
          error instanceof Error ? error.message : "Passkey sign-in failed",
        );
      } finally {
        setBiometricScanning(false);
      }
    })();
  };

  const handleRegisterPasskey = () => {
    void (async () => {
      if (!browserSupportsWebAuthn()) {
        setToast("Passkeys are not supported in this browser.");
        setToastType("error");
        return;
      }
      try {
        const optionsResponse = await fetch(`${API_URL}/v1/auth/passkey`, {
          method: "POST",
          credentials: "include",
          headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "FolioWeb",
          },
          body: JSON.stringify({ action: "register-options" }),
        });
        const options = await optionsResponse.json();
        if (!optionsResponse.ok)
          throw new Error(options.message || "Unable to start passkey setup");
        const registration = await startRegistration({
          optionsJSON: options.options,
        });
        const verifyResponse = await fetch(`${API_URL}/v1/auth/passkey`, {
          method: "POST",
          credentials: "include",
          headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "FolioWeb",
          },
          body: JSON.stringify({
            action: "register-verify",
            challengeId: options.challengeId,
            response: registration,
          }),
        });
        const result = await verifyResponse.json();
        if (!verifyResponse.ok)
          throw new Error(result.message || "Unable to save passkey");
        setToast("Passkey added. You can use it next time you sign in.");
        setToastType("success");
      } catch (error) {
        setToast(
          error instanceof Error ? error.message : "Passkey setup failed",
        );
        setToastType("error");
      }
    })();
  };

  if (authStep === "checking") {
    return (
      <main className="login-page">
        <div className="login-card">
          <div className="brand">
            <span>
              <FolderOpen size={19} />
            </span>
            <div>
              <b>Folio</b>
              <small>Checking your secure session...</small>
            </div>
          </div>
        </div>
      </main>
    );
  }

  if (authStep === "credentials") {
    return (
      <main className="login-page">
        <div className="login-card">
          <div className="brand">
            <span>
              <FolderOpen size={19} />
            </span>
            <div>
              <b>Folio</b>
              <small>Documents & study, together.</small>
            </div>
          </div>
          <h1>
            {authMode === "register"
              ? "Create your secure Folio."
              : "Welcome back to Folio."}
          </h1>
          <p>Sign in to your documents, courses and revision.</p>

          <form onSubmit={handleCredentialsSubmit} className="login-form">
            {authMode === "register" && (
              <label>
                Full Name
                <input
                  value={displayNameInput}
                  onChange={(e) => setDisplayNameInput(e.target.value)}
                  placeholder="Your full name"
                  autoComplete="name"
                  required
                  maxLength={120}
                />
              </label>
            )}
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

            {authError && (
              <div className="mfa-error-message">
                <AlertCircle size={14} />
                <span>{authError}</span>
              </div>
            )}

            <div className="mfa-notice">
              <ShieldCheck size={16} />
              <span>
                {authMode === "register"
                  ? "We will verify your account by email before creating your session."
                  : "A one-time email code is required after your password."}
              </span>
            </div>

            <button
              type="submit"
              className="primary full"
              disabled={authLoading}
            >
              {authLoading
                ? "Sending secure code..."
                : authMode === "register"
                  ? "Register securely"
                  : "Sign in securely"}{" "}
              <ArrowRight size={15} style={{ marginLeft: 6 }} />
            </button>
          </form>

          <button
            className="link"
            type="button"
            onClick={() => {
              setAuthMode(authMode === "login" ? "register" : "login");
              setAuthError("");
            }}
          >
            {authMode === "login"
              ? "New to Folio? Create an account"
              : "Already registered? Sign in"}
          </button>

          <div className="biometric-divider">
            <span>or</span>
          </div>

          <button
            className="biometric-login-btn"
            onClick={handleBiometricLogin}
            disabled={biometricScanning}
          >
            {biometricScanning ? (
              <>
                <ScanFace
                  size={20}
                  className={biometricDone ? "" : "pulse-scan"}
                  style={{
                    color: biometricDone ? "var(--success)" : "var(--teal)",
                  }}
                />
                <span>
                  {biometricDone
                    ? "Identity Verified"
                    : "Waiting for your passkey..."}
                </span>
              </>
            ) : (
              <>
                <Fingerprint size={20} style={{ color: "var(--teal)" }} />
                <span>Sign in with passkey</span>
              </>
            )}
          </button>

          <small className="login-foot">
            Your account is protected with email verification.
          </small>
        </div>
      </main>
    );
  }

  if (authStep === "mfa") {
    return (
      <main className="login-page">
        <div className="login-card mfa-card">
          <div className="mfa-header">
            <span>
              <Fingerprint size={28} style={{ color: "var(--teal)" }} />
            </span>
            <h2>Security MFA Code</h2>
            <p>
              We sent a 6-digit code to your email. Enter it to{" "}
              {authMode === "register"
                ? "verify your account and sign in"
                : "authorize your session"}
              .
            </p>
          </div>

          {toast && <p role="status">{toast}</p>}
          <div className="mfa-digits-container">
            {mfaDigits.map((digit, i) => (
              <input
                key={i}
                ref={(el) => {
                  mfaRefs.current[i] = el;
                }}
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

          <button
            onClick={() => handleVerifyMfa()}
            disabled={authLoading}
            className="primary full"
            style={{ marginTop: 10 }}
          >
            {authLoading
              ? "Verifying..."
              : authMode === "register"
                ? "Verify account & sign in"
                : "Authorize Session"}
          </button>

          <div className="mfa-timer-row">
            {mfaTimer > 0 ? (
              <span className="mfa-countdown-text">
                You can request a new code in <b>{mfaTimer}s</b>
              </span>
            ) : (
              <span className="mfa-countdown-expired">
                Didn&apos;t get it? You can request a new code.
              </span>
            )}

            <button
              onClick={handleResendMfa}
              disabled={mfaTimer > 0 || isResending}
              className="link resend-mfa-btn"
              style={{ opacity: mfaTimer > 0 ? 0.5 : 1 }}
            >
              {isResending ? (
                <RotateCw className="spin" size={13} />
              ) : (
                "Resend Token"
              )}
            </button>
          </div>

          <button
            className="link"
            onClick={() => {
              setAuthStep("credentials");
              setMfaError("");
            }}
          >
            Back to {authMode === "register" ? "registration" : "sign in"}
          </button>
        </div>
      </main>
    );
  }

  return authUser ? (
    <>
      {initialView === "admin" ? <AdminPage user={authUser} logout={handleLogout} /> : <Workspace
        key={authUser.id}
        user={authUser}
        logout={handleLogout}
        registerPasskey={handleRegisterPasskey}
      />}
      {toast && (
        <div className="ws-toast" role="status">
          {toast}
        </div>
      )}
    </>
  ) : null;
}
