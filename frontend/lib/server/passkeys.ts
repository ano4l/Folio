import { generateAuthenticationOptions, generateRegistrationOptions } from "@simplewebauthn/server";
import { randomUUID } from "node:crypto";
import { supabaseAdmin } from "./supabase";

export const PASSKEY_RP_NAME = "Folio";
export function passkeyRpId() {
  return process.env.WEBAUTHN_RP_ID || new URL(process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000").hostname;
}
export function passkeyOrigin() { return process.env.WEBAUTHN_ORIGIN || process.env.NEXT_PUBLIC_APP_URL || "http://localhost:3000"; }

export async function saveChallenge(userId: string | null, purpose: "REGISTER" | "LOGIN", challenge: string) {
  const { data, error } = await supabaseAdmin().from("passkey_challenges").insert({
    user_id: userId, purpose, challenge, expires_at: new Date(Date.now() + 5 * 60_000).toISOString(),
  }).select("id").single();
  if (error || !data) throw new Error(`Unable to save passkey challenge: ${error?.code || "unknown"}`);
  return data.id as string;
}

export async function consumeChallenge(id: string) {
  const { data, error } = await supabaseAdmin().from("passkey_challenges").select("id,user_id,purpose,challenge,expires_at,consumed_at")
    .eq("id", id).maybeSingle();
  if (error || !data || data.consumed_at || new Date(data.expires_at).getTime() <= Date.now()) return null;
  const { error: updateError } = await supabaseAdmin().from("passkey_challenges").update({ consumed_at: new Date().toISOString() }).eq("id", id).is("consumed_at", null);
  if (updateError) throw new Error(`Unable to consume passkey challenge: ${updateError.code}`);
  return data;
}

export function encodeBase64Url(value: Uint8Array) { return Buffer.from(value).toString("base64url"); }
export function decodeBase64Url(value: string) { return new Uint8Array(Buffer.from(value, "base64url")); }

export async function registrationOptions(user: { id: string; email: string; display_name: string }) {
  const supabase = supabaseAdmin();
  const { data: existing } = await supabase.from("passkey_credentials").select("credential_id").eq("user_id", user.id);
  const options = await generateRegistrationOptions({
    rpName: PASSKEY_RP_NAME, rpID: passkeyRpId(), userName: user.email, userDisplayName: user.display_name,
    userID: new Uint8Array(Buffer.from(user.id.replaceAll("-", ""), "hex")), attestationType: "none", authenticatorSelection: { residentKey: "required", userVerification: "required" },
    excludeCredentials: (existing || []).map(item => ({ id: item.credential_id })),
  });
  const challengeId = await saveChallenge(user.id, "REGISTER", options.challenge);
  return { challengeId, options };
}

export async function authenticationOptions(userId?: string) {
  const supabase = supabaseAdmin();
  let allowCredentials: { id: string; transports?: AuthenticatorTransport[] }[] | undefined;
  if (userId) {
    const { data } = await supabase.from("passkey_credentials").select("credential_id,transports").eq("user_id", userId);
    allowCredentials = (data || []).map(item => ({ id: item.credential_id, transports: item.transports as AuthenticatorTransport[] }));
  }
  const options = await generateAuthenticationOptions({ rpID: passkeyRpId(), userVerification: "required", allowCredentials });
  const challengeId = await saveChallenge(userId || null, "LOGIN", options.challenge);
  return { challengeId, options };
}
