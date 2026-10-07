import { NextRequest, NextResponse } from "next/server";
import { verifyAuthenticationResponse, verifyRegistrationResponse } from "@simplewebauthn/server";
import { ApiError, jsonError, readJson, requireMutationHeader } from "@/lib/server/api";
import { applySessionCookie, currentUser, hashSession, newSessionToken } from "@/lib/server/auth";
import { authenticationOptions, consumeChallenge, decodeBase64Url, encodeBase64Url, passkeyOrigin, passkeyRpId, registrationOptions } from "@/lib/server/passkeys";
import { supabaseAdmin } from "@/lib/server/supabase";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    requireMutationHeader(request);
    const { action } = await request.clone().json() as { action?: string };
    if (action === "register-options") return registerOptions(request);
    if (action === "register-verify") return registerVerify(request);
    if (action === "login-options") return loginOptions(request);
    if (action === "login-verify") return loginVerify(request);
    throw new ApiError(404, "Not found");
  } catch (error) { return jsonError(error); }
}

async function registerOptions(request: NextRequest) {
  const user = await currentUser(request);
  const { data, error } = await supabaseAdmin().from("app_users").select("id,email,display_name").eq("id", user.id).eq("verified", true).single();
  if (error || !data) throw new ApiError(401, "Authentication required");
  return NextResponse.json(await registrationOptions(data));
}

async function registerVerify(request: NextRequest) {
  const user = await currentUser(request);
  const body = await readJson<{ challengeId?: string; response?: unknown }>(request);
  if (!body.challengeId || !body.response) throw new ApiError(400, "Passkey registration is incomplete");
  const challenge = await consumeChallenge(body.challengeId);
  if (!challenge || challenge.purpose !== "REGISTER" || challenge.user_id !== user.id) throw new ApiError(400, "Passkey registration has expired");
  const verification = await verifyRegistrationResponse({ response: body.response as Parameters<typeof verifyRegistrationResponse>[0]["response"], expectedChallenge: challenge.challenge, expectedOrigin: passkeyOrigin(), expectedRPID: passkeyRpId() });
  if (!verification.verified || !verification.registrationInfo) throw new ApiError(400, "Passkey registration could not be verified");
  const { credential } = verification.registrationInfo;
  const { error } = await supabaseAdmin().from("passkey_credentials").insert({ user_id: user.id, credential_id: credential.id, public_key: encodeBase64Url(credential.publicKey), counter: credential.counter, transports: (body.response as { response?: { transports?: string[] } }).response?.transports || [] });
  if (error?.code === "23505") throw new ApiError(409, "This passkey is already registered");
  if (error) throw new Error(`Unable to save passkey: ${error.code}`);
  return NextResponse.json({ registered: true });
}

async function loginOptions(request: NextRequest) {
  const body = await readJson<{ email?: string }>(request);
  const email = body.email?.trim().toLowerCase();
  let userId: string | undefined;
  if (email) {
    const { data } = await supabaseAdmin().from("app_users").select("id").eq("email", email).eq("verified", true).maybeSingle();
    userId = data?.id;
  }
  return NextResponse.json(await authenticationOptions(userId));
}

async function loginVerify(request: NextRequest) {
  const body = await readJson<{ challengeId?: string; response?: unknown }>(request);
  if (!body.challengeId || !body.response) throw new ApiError(400, "Passkey authentication is incomplete");
  const challenge = await consumeChallenge(body.challengeId);
  if (!challenge || challenge.purpose !== "LOGIN") throw new ApiError(401, "Passkey sign-in has expired");
  const credentialId = (body.response as { id?: string }).id;
  if (!credentialId) throw new ApiError(401, "Passkey credential is missing");
  const { data: credential, error } = await supabaseAdmin().from("passkey_credentials").select("id,user_id,credential_id,public_key,counter").eq("credential_id", credentialId).maybeSingle();
  if (error || !credential) throw new ApiError(401, "This passkey is not registered with Folio");
  if (challenge.user_id && challenge.user_id !== credential.user_id) throw new ApiError(401, "This passkey belongs to another account");
  const verification = await verifyAuthenticationResponse({ response: body.response as Parameters<typeof verifyAuthenticationResponse>[0]["response"], expectedChallenge: challenge.challenge, expectedOrigin: passkeyOrigin(), expectedRPID: passkeyRpId(), credential: { id: credential.credential_id, publicKey: decodeBase64Url(credential.public_key), counter: Number(credential.counter) }, requireUserVerification: true });
  if (!verification.verified) throw new ApiError(401, "Passkey verification failed");
  const rawToken = newSessionToken();
  const { error: sessionError } = await supabaseAdmin().from("user_sessions").insert({ user_id: credential.user_id, token_hash: hashSession(rawToken), expires_at: new Date(Date.now() + 12 * 60 * 60_000).toISOString() });
  if (sessionError) throw new Error(`Unable to create session: ${sessionError.code}`);
  await supabaseAdmin().from("passkey_credentials").update({ counter: verification.authenticationInfo.newCounter, last_used_at: new Date().toISOString() }).eq("id", credential.id);
  const { data: user } = await supabaseAdmin().from("app_users").select("id,email,display_name").eq("id", credential.user_id).eq("verified", true).single();
  if (!user) throw new ApiError(401, "Account is not available");
  const response = NextResponse.json({ id: user.id, email: user.email, displayName: user.display_name });
  applySessionCookie(response, rawToken);
  return response;
}
