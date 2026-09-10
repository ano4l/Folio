import { createHash, createHmac, randomBytes, randomInt, randomUUID, timingSafeEqual } from "node:crypto";
import bcrypt from "bcryptjs";
import { NextRequest, NextResponse } from "next/server";
import { ApiError } from "./api";
import { supabaseAdmin } from "./supabase";

export const SESSION_COOKIE = "FOLIO_SESSION";
const OTP_MINUTES = 10;
const SESSION_HOURS = 12;

export type CurrentUser = { id: string; email: string; displayName: string; sessionHash: string };

function otpPepper() {
  const value = process.env.AUTH_OTP_PEPPER;
  if (!value || value.length < 32) throw new Error("AUTH_OTP_PEPPER must contain at least 32 characters");
  return value;
}
export function normalizeEmail(value: string) { return value.trim().toLowerCase(); }
export function hashPassword(value: string) { return bcrypt.hash(value, 12); }
export function checkPassword(value: string, hash: string) { return bcrypt.compare(value, hash); }
export function hashSession(value: string) { return createHash("sha256").update(value).digest("hex"); }
export function hashOtp(challengeId: string, code: string) {
  return createHmac("sha256", otpPepper()).update(`${challengeId}:${code}`).digest("hex");
}
export function secureEqual(left: string, right: string) {
  const a = Buffer.from(left), b = Buffer.from(right);
  return a.length === b.length && timingSafeEqual(a, b);
}

export async function sendOtp(user: { id: string; email: string; display_name: string }, purpose: "REGISTER" | "LOGIN") {
  const supabase = supabaseAdmin();
  const challengeId = randomUUID();
  const code = randomInt(0, 1_000_000).toString().padStart(6, "0");
  const expiresAt = new Date(Date.now() + OTP_MINUTES * 60_000).toISOString();
  const { error: insertError } = await supabase.from("otp_challenges").insert({
    id: challengeId, user_id: user.id, purpose, code_hash: hashOtp(challengeId, code), expires_at: expiresAt,
  });
  if (insertError) throw new Error(`Unable to create verification challenge: ${insertError.code}`);
  try {
    await deliverOtp(user.email, user.display_name, code, purpose, challengeId);
    await supabase.from("otp_challenges").update({ consumed_at: new Date().toISOString() })
      .eq("user_id", user.id).eq("purpose", purpose).is("consumed_at", null).neq("id", challengeId);
  } catch (error) {
    await supabase.from("otp_challenges").delete().eq("id", challengeId);
    throw error;
  }
  return { challengeId, destination: maskEmail(user.email), expiresInSeconds: OTP_MINUTES * 60, resendAfterSeconds: 60 };
}

async function deliverOtp(email: string, name: string, code: string, purpose: string, idempotencyKey: string) {
  const apiKey = process.env.RESEND_API_KEY, from = process.env.EMAIL_FROM;
  if (!apiKey || !from) throw new Error("Resend is not configured");
  const action = purpose === "REGISTER" ? "verify your new Folio account" : "finish signing in to Folio";
  const safeName = name.replace(/[&<>"']/g, character => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" }[character]!));
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json", "Idempotency-Key": `folio-otp/${idempotencyKey}` },
    body: JSON.stringify({ from, to: [email], subject: "Your Folio verification code",
      html: `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto"><h2>Folio security code</h2><p>Hello ${safeName}, use this code to ${action}:</p><p style="font-size:32px;letter-spacing:8px;font-weight:700">${code}</p><p>This code expires in ${OTP_MINUTES} minutes. If you did not request it, you can ignore this email.</p></div>` }),
    signal: AbortSignal.timeout(12_000),
  });
  if (!response.ok) throw new Error(`Resend rejected the message (${response.status})`);
}

export function applySessionCookie(response: NextResponse, rawToken: string, maxAge = SESSION_HOURS * 3600) {
  response.cookies.set(SESSION_COOKIE, rawToken, { httpOnly: true, secure: process.env.NODE_ENV === "production", sameSite: "lax", path: "/", maxAge });
}

export async function currentUser(request: NextRequest): Promise<CurrentUser> {
  const raw = request.cookies.get(SESSION_COOKIE)?.value;
  if (!raw) throw new ApiError(401, "Authentication required");
  const sessionHash = hashSession(raw), supabase = supabaseAdmin();
  const { data: session, error } = await supabase.from("user_sessions").select("user_id")
    .eq("token_hash", sessionHash).is("revoked_at", null).gt("expires_at", new Date().toISOString()).maybeSingle();
  if (error || !session) throw new ApiError(401, "Authentication required");
  const { data: user, error: userError } = await supabase.from("app_users").select("id,email,display_name,verified")
    .eq("id", session.user_id).eq("verified", true).maybeSingle();
  if (userError || !user) throw new ApiError(401, "Authentication required");
  return { id: user.id, email: user.email, displayName: user.display_name, sessionHash };
}

export function newSessionToken() { return randomBytes(32).toString("base64url"); }
function maskEmail(email: string) { const at = email.indexOf("@"); return `${email.slice(0, Math.min(2, at))}***${email.slice(at)}`; }
