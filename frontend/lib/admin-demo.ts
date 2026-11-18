import type { AdminAccount, AdminOverview, AdminPageData, AdminSession, AdminUsage, AdminUser } from "./admin-types";

// These public credentials open fictional browser data only. They are not Folio account credentials.
export const DEMO_ADMIN_EMAIL = "admin.demo@example.com";
export const DEMO_ADMIN_PASSWORD = "FolioDemo2026!";
export const DEMO_ADMIN_USER = {
  id: "10000000-0000-4000-8000-000000000000",
  email: DEMO_ADMIN_EMAIL,
  displayName: "Folio Demo Admin",
  isAdmin: true,
};

export type AdminDemoData = {
  now: number;
  users: AdminUser[];
  sessions: AdminSession[];
  usage: AdminUsage[];
};

const DAY = 86_400_000;
const names = [
  "Amahle Dlamini", "Lethabo Mokoena", "Sipho Nkosi", "Naledi Molefe",
  "Thando Ndlovu", "Kabelo Maseko", "Zinhle Khumalo", "Bongani Sithole",
  "Lerato Moremi", "Sibusiso Zulu", "Palesa Mahlangu", "Andile Mthembu",
  "Nomsa Hadebe", "Karabo Radebe", "Ayanda Cele", "Tshepo Modise",
  "Nandi Buthelezi", "Mpho Mosweu", "Siyabonga Mkhize", "Refilwe Tau",
  "Busisiwe Gumede", "Themba Zwane", "Keabetswe Motsepe", "Nokuthula Mthethwa",
  "Vuyo Jacobs", "Neo Mofokeng", "Nosipho Madlala", "Tumi Sebola",
  "Sanele Mhlongo", "Boitumelo Phiri", "Unathi Gqoboka", "Dineo Letsoalo",
];
const id = (group: string, index: number) => `${group}-0000-4000-8000-${String(index).padStart(12, "0")}`;
const newestFirst = <T extends { id: string; createdAt: string }>(rows: T[]) => rows.sort((a, b) => b.createdAt.localeCompare(a.createdAt) || a.id.localeCompare(b.id));
const account = (user: AdminUser): AdminAccount => ({ id: user.id, email: user.email, displayName: user.displayName });

/** A fixed snapshot keeps demo totals, dates and filters consistent for the whole visit. */
export function createAdminDemoData(now = Date.now()): AdminDemoData {
  const at = (daysAgo: number) => new Date(now - daysAgo * DAY).toISOString();
  const users: AdminUser[] = [
    { ...DEMO_ADMIN_USER, verified: true, createdAt: at(240) },
    ...names.map((displayName, index) => ({
      id: id("10000000", index + 1),
      email: `${displayName.toLowerCase().replace(/ /g, ".")}@example.com`,
      displayName,
      verified: (index + 1) % 6 !== 0,
      createdAt: at((index + 1) % 6 === 0 ? 1 + index / 10 : 180 - index * 4),
      isAdmin: false,
    })),
  ];
  const sessions: AdminSession[] = [];
  const usage: AdminUsage[] = [];
  users.filter(user => user.verified).forEach((user, index) => {
    const joinedDays = (now - Date.parse(user.createdAt)) / DAY;
    const ageLimit = Math.min(100, joinedDays - 1);
    for (let visit = 0; visit < 3; visit++) {
      const daysAgo = visit === 0 && index % 3 === 0 ? 0.01 : 1 + ((index * 7 + visit * 17) % ageLimit);
      const revoked = visit === 2 && index % 4 === 0;
      sessions.push({
        id: id("20000000", sessions.length + 1),
        user: account(user),
        createdAt: at(daysAgo),
        expiresAt: at(daysAgo - 0.5),
        revokedAt: revoked ? at(daysAgo - 0.2) : null,
        status: revoked ? "Revoked" : daysAgo < 0.5 ? "Active" : "Expired",
      });
    }
    for (let request = 0; request < 4; request++) {
      const abstained = (index + request) % 11 === 0;
      usage.push({
        id: id("30000000", usage.length + 1),
        user: account(user),
        createdAt: at(0.02 + ((index * 5 + request * 19) % ageLimit)),
        model: request % 3 === 0 ? "openrouter/free" : "llama-3.3-70b-versatile",
        grounded: !abstained,
        abstained,
      });
    }
  });
  return { now, users: newestFirst(users), sessions: newestFirst(sessions), usage: newestFirst(usage) };
}

/** Mirrors the read-only admin filters without making API or database calls. */
export function readAdminDemo(data: AdminDemoData, query: URLSearchParams): AdminOverview | AdminPageData<AdminUser | AdminSession | AdminUsage> {
  const view = query.get("view") || "overview";
  const recent = (row: { createdAt: string }, days: number) => Date.parse(row.createdAt) >= data.now - days * DAY;
  if (view === "overview") return {
    totalUsers: data.users.length,
    verifiedUsers: data.users.filter(user => user.verified).length,
    activeSessions: data.sessions.filter(session => session.status === "Active").length,
    sessionsLast30Days: data.sessions.filter(row => recent(row, 30)).length,
    recordedAiRequests: data.usage.length,
    aiRequestsLast30Days: data.usage.filter(row => recent(row, 30)).length,
  };
  if (!["users", "sessions", "usage"].includes(view)) throw new Error("Unknown demo view");
  const positiveInteger = (key: string, fallback: number, max: number) => {
    const raw = query.get(key);
    if (raw === null) return fallback;
    if (!/^[1-9]\d*$/.test(raw) || Number(raw) > max) throw new Error(`Invalid ${key}`);
    return Number(raw);
  };
  const page = positiveInteger("page", 1, 100000);
  const pageSize = positiveInteger("pageSize", 25, 100);
  const userId = query.get("userId") || "";
  let rows: Array<AdminUser | AdminSession | AdminUsage>;
  if (view === "users") {
    const search = (query.get("search") || "").trim().toLowerCase();
    rows = data.users.filter(user => (!userId || user.id === userId) && (!search || `${user.displayName}\n${user.email}`.toLowerCase().includes(search)));
  } else {
    const days = query.get("days") || "30";
    if (!["7", "30", "90", "all"].includes(days)) throw new Error("Invalid date filter");
    rows = (view === "sessions" ? data.sessions : data.usage).filter(row => (!userId || row.user.id === userId) && (days === "all" || recent(row, Number(days))));
  }
  return { items: rows.slice((page - 1) * pageSize, page * pageSize), total: rows.length, page, pageSize };
}
