import assert from "node:assert/strict";
import test from "node:test";
import { createAdminDemoData, DEMO_ADMIN_EMAIL, DEMO_ADMIN_USER, readAdminDemo } from "./admin-demo.ts";
import type { AdminOverview, AdminPageData, AdminSession, AdminUsage, AdminUser } from "./admin-types";

const now = Date.parse("2026-11-17T10:00:00Z");
const fixture = createAdminDemoData(now);
const readPage = (query: string) => readAdminDemo(fixture, new URLSearchParams(query)) as AdminPageData<AdminUser | AdminSession | AdminUsage>;

test("demo records are fictional, internally consistent and use one fixed snapshot", () => {
  assert.deepEqual(createAdminDemoData(now), fixture);
  assert.equal(fixture.users.length, 33);
  assert.ok(fixture.users.some(user => user.email === DEMO_ADMIN_EMAIL && user.isAdmin));
  assert.ok(fixture.users.every(user => user.email.endsWith("@example.com")));
  const users = new Map(fixture.users.map(user => [user.id, user]));
  const allIds = [...fixture.users, ...fixture.sessions, ...fixture.usage].map(row => row.id);
  assert.equal(new Set(allIds).size, allIds.length);
  for (const uuid of allIds) assert.match(uuid, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  for (const row of [...fixture.sessions, ...fixture.usage]) {
    const user = users.get(row.user.id)!;
    assert.ok(user.verified);
    assert.equal(row.user.email, user.email);
    assert.ok(Date.parse(user.createdAt) <= Date.parse(row.createdAt));
    assert.ok(Date.parse(row.createdAt) <= now);
  }
  assert.deepEqual(new Set(fixture.sessions.map(row => row.status)), new Set(["Active", "Expired", "Revoked"]));
  assert.ok(fixture.usage.some(row => row.abstained));
  assert.ok(fixture.usage.some(row => row.grounded));
});

test("overview totals match the same records shown in tables", () => {
  const overview = readAdminDemo(fixture, new URLSearchParams()) as AdminOverview;
  assert.equal(overview.totalUsers, readPage("view=users").total);
  assert.equal(overview.verifiedUsers, fixture.users.filter(user => user.verified).length);
  assert.equal(overview.activeSessions, fixture.sessions.filter(session => session.status === "Active").length);
  assert.equal(overview.sessionsLast30Days, readPage("view=sessions&days=30").total);
  assert.equal(overview.recordedAiRequests, readPage("view=usage&days=all").total);
  assert.equal(overview.aiRequestsLast30Days, readPage("view=usage&days=30").total);
});

test("user search is case-insensitive, paginates without repeats and supports empty results", () => {
  const first = readPage("view=users");
  const second = readPage("view=users&page=2");
  assert.equal(first.items.length, 25);
  assert.equal(second.items.length, 8);
  assert.equal(new Set([...first.items, ...second.items].map(row => row.id)).size, 33);
  const found = readPage("view=users&search=%20AMAHLE%20");
  assert.equal(found.total, 1);
  assert.equal((found.items[0] as AdminUser).displayName, "Amahle Dlamini");
  assert.equal(readPage("view=users&search=admin.demo%40example.com").items[0].id, DEMO_ADMIN_USER.id);
  assert.equal(readPage("view=users&search=nobody-matches").total, 0);
});

test("activity periods and account drilldowns select only matching records", () => {
  for (const view of ["sessions", "usage"]) {
    const totals = ["7", "30", "90", "all"].map(days => readPage(`view=${view}&days=${days}`).total);
    assert.ok(totals[0] > 0);
    assert.ok(totals[0] < totals[1] && totals[1] < totals[2] && totals[2] < totals[3]);
    const filtered = readPage(`view=${view}&days=all&userId=${DEMO_ADMIN_USER.id}`);
    assert.equal(filtered.total, view === "sessions" ? 3 : 4);
    assert.ok(filtered.items.every(row => (row as AdminSession | AdminUsage).user.id === DEMO_ADMIN_USER.id));
    for (const row of readPage(`view=${view}&days=7&pageSize=100`).items) {
      assert.ok(Date.parse(row.createdAt) >= now - 7 * 86400000);
    }
  }
  const pending = fixture.users.find(user => !user.verified)!;
  assert.equal(readPage(`view=sessions&days=all&userId=${pending.id}`).total, 0);
  assert.equal(readPage(`view=usage&days=all&userId=${pending.id}`).total, 0);
});

test("demo reader rejects invalid page sizes and unknown views", () => {
  for (const query of ["view=documents", "view=users&page=0", "view=users&pageSize=101", "view=users&page=1.5", "view=sessions&days=365"]) {
    assert.throws(() => readPage(query), Error, query);
  }
});
