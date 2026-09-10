import { NextRequest, NextResponse } from "next/server";
import { ApiError, jsonError, readJson, requireMutationHeader } from "@/lib/server/api";
import { applySessionCookie, checkPassword, currentUser, hashOtp, hashPassword, hashSession, newSessionToken, normalizeEmail, sendOtp, SESSION_COOKIE } from "@/lib/server/auth";
import { supabaseAdmin } from "@/lib/server/supabase";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

type AuthBody = { displayName?: string; email?: string; password?: string; challengeId?: string; code?: string };

export async function GET(request: NextRequest, { params }: { params: Promise<{ action: string }> }) {
  try {
    const { action } = await params;
    if (action !== "me") throw new ApiError(404, "Not found");
    const user = await currentUser(request);
    return NextResponse.json({ id: user.id, email: user.email, displayName: user.displayName });
  } catch (error) { return jsonError(error); }
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ action: string }> }) {
  try {
    const { action } = await params;
    requireMutationHeader(request);
    if (action === "register") return register(request);
    if (action === "login") return login(request);
    if (action === "verify") return verify(request);
    if (action === "resend") return resend(request);
    if (action === "logout") return logout(request);
    throw new ApiError(404, "Not found");
  } catch (error) { return jsonError(error); }
}

async function register(request: NextRequest) {
  const body = await readJson<AuthBody>(request);
  const email = normalizeAndValidateEmail(body.email), name = body.displayName?.trim() || "";
  validatePassword(body.password);
  if (!name || name.length > 120) throw new ApiError(400, "Enter your full name");
  const supabase = supabaseAdmin();
  const { data: existing, error: findError } = await supabase.from("app_users").select("id,email,display_name,verified")
    .eq("email", email).maybeSingle();
  if (findError) throw new Error(`Unable to check account: ${findError.code}`);
  if (existing?.verified) throw new ApiError(409, "An account already exists for this email");
  const passwordHash = await hashPassword(body.password!);
  let user: { id: string; email: string; display_name: string };
  if (existing) {
    const { data, error } = await supabase.from("app_users").update({ display_name: name, password_hash: passwordHash })
      .eq("id", existing.id).eq("verified", false).select("id,email,display_name").single();
    if (error) throw new Error(`Unable to update registration: ${error.code}`);
    user = data;
  } else {
    const { data, error } = await supabase.from("app_users").insert({ email, display_name: name, password_hash: passwordHash })
      .select("id,email,display_name").single();
    if (error?.code === "23505") throw new ApiError(409, "An account already exists for this email");
    if (error) throw new Error(`Unable to register account: ${error.code}`);
    user = data;
  }
  return NextResponse.json(await sendOtp(user, "REGISTER"));
}

async function login(request: NextRequest) {
  const body = await readJson<AuthBody>(request);
  const email = normalizeAndValidateEmail(body.email);
  if (!body.password) throw new ApiError(400, "Enter your password");
  const supabase = supabaseAdmin();
  const { data: user, error } = await supabase.from("app_users").select("id,email,display_name,password_hash,verified")
    .eq("email", email).maybeSingle();
  if (error) throw new Error(`Unable to read account: ${error.code}`);
  if (!user || !(await checkPassword(body.password, user.password_hash))) throw new ApiError(401, "Email or password is incorrect");
  if (!user.verified) throw new ApiError(403, "Verify this account before signing in");
  return NextResponse.json(await sendOtp(user, "LOGIN"));
}

async function verify(request: NextRequest) {
  const body = await readJson<AuthBody>(request);
  if (!body.challengeId || !/^[0-9a-f-]{36}$/i.test(body.challengeId)) throw new ApiError(400, "Invalid verification request");
  if (!body.code || !/^\d{6}$/.test(body.code)) throw new ApiError(400, "Enter the 6-digit code");
  const rawToken = newSessionToken(), expiresAt = new Date(Date.now() + 12 * 60 * 60_000).toISOString();
  const { data, error } = await supabaseAdmin().rpc("verify_folio_otp", {
    p_challenge_id: body.challengeId, p_code_hash: hashOtp(body.challengeId, body.code),
    p_session_token_hash: hashSession(rawToken), p_session_expires_at: expiresAt,
  });
  if (error) throw new Error(`Unable to verify code: ${error.code}`);
  const result = (data as Array<{ status: string; user_id: string | null; email: string | null; display_name: string | null }> | null)?.[0];
  if (!result || result.status === "NOT_FOUND") throw new ApiError(404, "Verification request not found");
  if (result.status === "INVALID") throw new ApiError(401, "The verification code is incorrect");
  if (result.status === "EXPIRED") throw new ApiError(410, "This code has expired");
  if (result.status === "LOCKED") throw new ApiError(429, "Too many incorrect attempts; request a new code");
  if (result.status !== "VERIFIED" || !result.user_id || !result.email || !result.display_name) throw new ApiError(409, "This verification request cannot be used");
  const response = NextResponse.json({ id: result.user_id, email: result.email, displayName: result.display_name });
  applySessionCookie(response, rawToken);
  return response;
}

async function resend(request: NextRequest) {
  const body = await readJson<AuthBody>(request);
  if (!body.challengeId) throw new ApiError(400, "Verification request is required");
  const supabase = supabaseAdmin();
  const { data: challenge, error } = await supabase.from("otp_challenges").select("id,user_id,purpose,created_at,consumed_at")
    .eq("id", body.challengeId).maybeSingle();
  if (error || !challenge) throw new ApiError(404, "Verification request not found");
  if (challenge.consumed_at) throw new ApiError(409, "Verification request has already been used");
  if (Date.now() - new Date(challenge.created_at).getTime() < 60_000) throw new ApiError(429, "Please wait before requesting another code");
  const { data: user, error: userError } = await supabase.from("app_users").select("id,email,display_name").eq("id", challenge.user_id).single();
  if (userError) throw new Error(`Unable to read account: ${userError.code}`);
  return NextResponse.json(await sendOtp(user, challenge.purpose as "REGISTER" | "LOGIN"));
}

async function logout(request: NextRequest) {
  const raw = request.cookies.get(SESSION_COOKIE)?.value;
  if (raw) await supabaseAdmin().from("user_sessions").update({ revoked_at: new Date().toISOString() }).eq("token_hash", hashSession(raw));
  const response = NextResponse.json({ loggedOut: true });
  applySessionCookie(response, "", 0);
  return response;
}

function normalizeAndValidateEmail(value?: string) {
  if (!value || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) || value.length > 320) throw new ApiError(400, "Enter a valid email address");
  return normalizeEmail(value);
}
function validatePassword(value?: string) {
  if (!value || value.length < 10 || value.length > 128) throw new ApiError(400, "Password must be between 10 and 128 characters");
}
