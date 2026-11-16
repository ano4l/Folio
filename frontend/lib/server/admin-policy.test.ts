import assert from "node:assert/strict";
import test from "node:test";
import { isAdminEmail, parseAdminFilters, sessionStatus } from "./admin-policy.ts";

test("admin access requires an exact configured email and defaults to denied", () => {
  assert.equal(isAdminEmail("anotida@virtukey.co.za", ""), false);
  assert.equal(isAdminEmail(" ANOTIDA@virtukey.co.za ", "one@example.com, anotida@virtukey.co.za"), true);
  for (const email of ["", "other@virtukey.co.za", "anotida@virtukey.co.za.evil.com", "prefix-anotida@virtukey.co.za"])
    assert.equal(isAdminEmail(email, "anotida@virtukey.co.za"), false);
});

test("session status distinguishes expiry from revocation without treating sessions as online", () => {
  const now = Date.parse("2026-10-21T12:00:00Z");
  assert.equal(sessionStatus({ revoked_at: null, expires_at: "2026-10-21T13:00:00Z" }, now), "Active");
  assert.equal(sessionStatus({ revoked_at: null, expires_at: "2026-10-21T12:00:00Z" }, now), "Expired");
  assert.equal(sessionStatus({ revoked_at: "2026-10-21T11:00:00Z", expires_at: "2026-10-21T13:00:00Z" }, now), "Revoked");
});

test("admin filters reject filter injection, unbounded pages and invalid identities", () => {
  for (const raw of ["search=x*,verified.eq.true", "search=%25", "search=x(y)", "userId=not-a-uuid", "view=documents", "page=0", "page=-1", "page=1.5", "page=100001", "pageSize=101", "days=365"])
    assert.throws(() => parseAdminFilters(new URLSearchParams(raw)), Error, raw);
  assert.deepEqual(parseAdminFilters(new URLSearchParams("view=users&search=Anotida%20Dzinotyiwei")), {
    view: "users", page: 1, pageSize: 25, search: "Anotida Dzinotyiwei", userId: "", days: "30",
  });
  assert.equal(parseAdminFilters(new URLSearchParams("days=all&pageSize=100&search=ren%C3%A9e%40example.com")).search, "renée@example.com");
  assert.equal(parseAdminFilters(new URLSearchParams("search=first_last%40example.com")).search, "first_last@example.com");
});
