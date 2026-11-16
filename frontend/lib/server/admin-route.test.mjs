import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import ts from "typescript";

const require = createRequire(import.meta.url);
const { NextRequest } = require("next/server");
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const adminId = "11111111-1111-4111-8111-111111111111";
const memberId = "22222222-2222-4222-8222-222222222222";
const hash = value => createHash("sha256").update(value).digest("hex");

// Execute the actual route and auth code. Only the database transport is replaced.
function fixture() {
  const now = Date.now(), date = offset => new Date(now + offset).toISOString();
  const users = [
    { id: adminId, email: "anotida@virtukey.co.za", display_name: "Admin", verified: true, created_at: date(-100000), password_hash: "PRIVATE_PASSWORD" },
    { id: memberId, email: "student@example.com", display_name: "Student", verified: false, created_at: date(-50000), password_hash: "PRIVATE_PASSWORD" },
  ];
  const session = (id, user_id, token, extra = {}) => ({ id, user_id, token_hash: hash(token), created_at: date(-10000), expires_at: date(100000), revoked_at: null, ...extra });
  const tables = {
    app_users: users,
    user_sessions: [session("s1", adminId, "admin"), session("s2", memberId, "member"), session("s3", adminId, "expired", { expires_at: date(-1) }), session("s4", adminId, "revoked", { revoked_at: date(-1) })],
    ai_queries: [
      { id: "q1", user_id: adminId, created_at: date(-1000), grounded: true, abstained: false, model: "test/model", source_count: 1, content: "PRIVATE_CONTENT" },
      { id: "q2", user_id: memberId, created_at: date(-10000), grounded: true, abstained: false, model: "test/model", source_count: 1, content: "PRIVATE_CONTENT" },
    ],
  };
  const calls = [];
  const db = { from(table) {
    assert.ok(Object.hasOwn(tables, table), `Forbidden admin table: ${table}`);
    const call = { table, columns: "" }; calls.push(call);
    let rows = [...tables[table]], options = {}, from = 0, to = Infinity, single = false;
    const query = {
      select(columns, opts = {}) { call.columns = columns; options = opts; return query; },
      eq(key, value) { rows = rows.filter(row => row[key] === value); return query; },
      is(key, value) { return query.eq(key, value); },
      gt(key, value) { rows = rows.filter(row => row[key] > value); return query; },
      gte(key, value) { rows = rows.filter(row => row[key] >= value); return query; },
      in(key, values) { rows = rows.filter(row => values.includes(row[key])); return query; },
      or(filter) {
        const terms = filter.split(",").map(term => term.split(".ilike.*"));
        rows = rows.filter(row => terms.some(([key, term]) => String(row[key]).toLowerCase().includes(term.slice(0, -1).toLowerCase())));
        return query;
      },
      order() { return query; },
      range(start, end) { from = start; to = end; return query; },
      maybeSingle() { single = true; return query; },
      then(resolve, reject) {
        const projected = rows.slice(from, to + 1).map(row => Object.fromEntries(call.columns.split(",").map(key => [key, row[key]])));
        return Promise.resolve({ data: options.head ? null : single ? projected[0] || null : projected, error: null, count: options.count ? rows.length : null }).then(resolve, reject);
      },
    };
    return query;
  } };
  const cache = new Map();
  function load(file) {
    if (file === path.join(root, "lib/server/supabase.ts")) return { supabaseAdmin: () => db };
    if (cache.has(file)) return cache.get(file).exports;
    const module = { exports: {} }; cache.set(file, module);
    const output = ts.transpileModule(readFileSync(file, "utf8"), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, esModuleInterop: true } }).outputText;
    const localRequire = specifier => {
      if (specifier.startsWith("@/")) return load(path.join(root, specifier.slice(2) + ".ts"));
      if (specifier.startsWith(".")) return load(path.resolve(path.dirname(file), specifier + ".ts"));
      return require(specifier);
    };
    new Function("require", "module", "exports", output)(localRequire, module, module.exports);
    return module.exports;
  }
  const { GET } = load(path.join(root, "app/api/v1/admin/route.ts"));
  return { calls, tables, request: (token, query = "") => GET(new NextRequest(`http://localhost/api/v1/admin${query}`, { headers: token ? { Cookie: `FOLIO_SESSION=${token}`, "X-Admin": "true" } : {} })) };
}

test("admin route enforces authentication, verification, expiry and revocation before cross-user reads", async () => {
  const original = process.env.FOLIO_ADMIN_EMAILS;
  process.env.FOLIO_ADMIN_EMAILS = "anotida@virtukey.co.za";
  try {
    for (const token of [null, "invalid", "expired", "revoked", "member"]) {
      const app = fixture(), response = await app.request(token, "?view=users");
      assert.equal(response.status, 401, String(token));
      assert.ok(app.calls.every(call => call.table !== "ai_queries"));
    }
    const app = fixture();
    app.tables.app_users[1].verified = true;
    assert.equal((await app.request("member", "?view=users")).status, 403);
    assert.equal(app.calls.length, 2, "non-admin only reads its session and account");
    process.env.FOLIO_ADMIN_EMAILS = "";
    assert.equal((await fixture().request("admin", "?view=overview")).status, 403);
  } finally { if (original === undefined) delete process.env.FOLIO_ADMIN_EMAILS; else process.env.FOLIO_ADMIN_EMAILS = original; }
});

test("admin route paginates all accounts and exposes only approved metadata", async () => {
  const original = process.env.FOLIO_ADMIN_EMAILS;
  process.env.FOLIO_ADMIN_EMAILS = "anotida@virtukey.co.za";
  try {
    const app = fixture();
    const overview = await (await app.request("admin")).json();
    assert.deepEqual(overview, { totalUsers: 2, verifiedUsers: 1, activeSessions: 2, sessionsLast30Days: 4, recordedAiRequests: 2, aiRequestsLast30Days: 2 });
    const usersResponse = await app.request("admin", "?view=users&pageSize=1&page=2");
    assert.equal(usersResponse.headers.get("cache-control"), "private, no-store");
    const users = await usersResponse.json();
    assert.equal(users.total, 2);
    assert.equal(users.items.length, 1);
    assert.equal(users.items[0].verified, false, "unverified accounts remain visible");
    const found = await (await app.request("admin", "?view=users&search=Student")).json();
    assert.equal(found.items[0].id, memberId);
    for (const view of ["sessions", "usage"]) {
      const result = await (await app.request("admin", `?view=${view}&days=all&userId=${memberId}`)).json();
      assert.equal(result.total, 1);
      assert.equal(result.items[0].user.id, memberId);
      assert.doesNotMatch(JSON.stringify(result), /password|token_hash|PRIVATE|source_count|document/i);
    }
    assert.doesNotMatch(JSON.stringify(users), /password|token_hash|PRIVATE/i);
    assert.ok(app.calls.every(call => !call.columns.includes("*") && !call.columns.includes("password_hash")));
    assert.equal((await app.request("admin", "?view=documents")).status, 400);
    assert.equal((await app.request("admin", "?view=users&search=a*,verified.eq.true")).status, 400);
  } finally { if (original === undefined) delete process.env.FOLIO_ADMIN_EMAILS; else process.env.FOLIO_ADMIN_EMAILS = original; }
});
