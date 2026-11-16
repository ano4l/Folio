import test from "node:test";
import assert from "node:assert/strict";

// Run against a locally started Folio API. No account is created and no email
// is sent: every request below must fail before account mutation/delivery.
const base = process.env.FOLIO_TEST_API_URL ?? "http://127.0.0.1:3000/api";

for (const action of ["register", "login", "verify", "resend"]) {
  test(`${action} returns JSON validation feedback for an invalid request`, async () => {
    const response = await fetch(`${base}/v1/auth/${action}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" },
      body: "{}",
    });
    assert.equal(response.status, 400);
    assert.match(response.headers.get("content-type") ?? "", /application\/json/);
    const result = await response.json();
    assert.equal(typeof result.message, "string");
    assert.ok(result.message.length > 0);
  });
}

test("malformed login JSON returns a recoverable JSON error", async () => {
  const response = await fetch(`${base}/v1/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" },
    body: "{",
  });
  assert.equal(response.status, 400);
  assert.equal((await response.json()).message, "Invalid JSON request");
});

test("logout retains request verification", async () => {
  const response = await fetch(`${base}/v1/auth/logout`, { method: "POST" });
  assert.equal(response.status, 403);
  assert.equal((await response.json()).message, "Missing browser request verification");
});

for (const [action, status] of [["register-options", 401], ["register-verify", 401], ["login-verify", 400]]) {
  test(`passkey ${action} returns a structured rejection`, async () => {
    const response = await fetch(`${base}/v1/auth/passkey`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" },
      body: JSON.stringify({ action }),
    });
    assert.equal(response.status, status);
    assert.equal(typeof (await response.json()).message, "string");
  });
}

test("malformed passkey JSON returns validation feedback", async () => {
  const response = await fetch(`${base}/v1/auth/passkey`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Requested-With": "FolioWeb" },
    body: "{",
  });
  assert.equal(response.status, 400);
  assert.equal((await response.json()).message, "Invalid JSON request");
});
