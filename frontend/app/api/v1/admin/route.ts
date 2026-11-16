import { NextRequest, NextResponse } from "next/server";
import { ApiError, jsonError } from "@/lib/server/api";
import { requireAdmin } from "@/lib/server/admin";
import { isAdminEmail, parseAdminFilters, sessionStatus } from "@/lib/server/admin-policy";
import { supabaseAdmin } from "@/lib/server/supabase";
import type { AdminAccount, AdminOverview, AdminSession, AdminUsage, AdminUser } from "@/lib/admin-types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
const headers = { "Cache-Control": "private, no-store", Vary: "Cookie" };

export async function GET(request: NextRequest) {
  try {
    // Authenticate before reading any cross-account information or parsing filters.
    await requireAdmin(request);
    let filters: ReturnType<typeof parseAdminFilters>;
    try { filters = parseAdminFilters(request.nextUrl.searchParams); }
    catch (error) { throw new ApiError(400, error instanceof Error ? error.message : "Invalid filters"); }
    const db = supabaseAdmin();
    const now = new Date().toISOString();
    if (filters.view === "overview") {
      const since = new Date(Date.now() - 30 * 86400000).toISOString();
      const results = await Promise.all([
        db.from("app_users").select("id", { count: "exact", head: true }),
        db.from("app_users").select("id", { count: "exact", head: true }).eq("verified", true),
        db.from("user_sessions").select("id", { count: "exact", head: true }).is("revoked_at", null).gt("expires_at", now),
        db.from("user_sessions").select("id", { count: "exact", head: true }).gte("created_at", since),
        db.from("ai_queries").select("id", { count: "exact", head: true }),
        db.from("ai_queries").select("id", { count: "exact", head: true }).gte("created_at", since),
      ]);
      for (const result of results) if (result.error || result.count === null) throw new Error("Unable to load admin overview");
      const counts = results.map(result => result.count!);
      const overview: AdminOverview = { totalUsers: counts[0], verifiedUsers: counts[1], activeSessions: counts[2], sessionsLast30Days: counts[3], recordedAiRequests: counts[4], aiRequestsLast30Days: counts[5] };
      return NextResponse.json(overview, { headers });
    }
    const { view, page, pageSize, userId, days, search } = filters;
    const from = (page - 1) * pageSize;
    if (view === "users") {
      let query = db.from("app_users").select("id,email,display_name,verified,created_at", { count: "exact" });
      if (search) {
        const pattern = search.replace(/_/g, "\\_");
        query = query.or(`email.ilike.*${pattern}*,display_name.ilike.*${pattern}*`);
      }
      if (userId) query = query.eq("id", userId);
      const { data, error, count } = await query.order("created_at", { ascending: false }).order("id").range(from, from + pageSize - 1);
      if (error || count === null) throw new Error("Unable to load admin users");
      const items: AdminUser[] = (data || []).map(row => ({ id: row.id, email: row.email, displayName: row.display_name, verified: row.verified, createdAt: row.created_at, isAdmin: isAdminEmail(row.email) }));
      return NextResponse.json({ items, total: count, page, pageSize }, { headers });
    }
    // Explicit column lists: no token hashes, prompts, answers, sources or vault data.
    const columns = view === "sessions" ? "id,user_id,created_at,expires_at,revoked_at" : "id,user_id,created_at,model,grounded,abstained";
    let query = db.from(view === "sessions" ? "user_sessions" : "ai_queries").select(columns, { count: "exact" });
    if (userId) query = query.eq("user_id", userId);
    if (days !== "all") query = query.gte("created_at", new Date(Date.now() - Number(days) * 86400000).toISOString());
    const { data, error, count } = await query.order("created_at", { ascending: false }).order("id").range(from, from + pageSize - 1);
    if (error || count === null) throw new Error("Unable to load admin activity");
    type ActivityRow = { id: string; user_id: string; created_at: string; expires_at: string; revoked_at: string | null; model: string | null; grounded: boolean; abstained: boolean };
    const rows = (data || []) as unknown as ActivityRow[];
    const users = new Map<string, AdminAccount>();
    if (rows.length) {
      const accounts = await db.from("app_users").select("id,email,display_name").in("id", [...new Set(rows.map(row => row.user_id))]);
      if (accounts.error) throw new Error("Unable to load activity accounts");
      for (const row of accounts.data || []) users.set(row.id, { id: row.id, email: row.email, displayName: row.display_name });
    }
    const items: Array<AdminSession | AdminUsage> = rows.map(row => {
      const user = users.get(row.user_id);
      if (!user) throw new Error("Activity account is unavailable");
      return view === "sessions"
        ? { id: row.id, user, createdAt: row.created_at, expiresAt: row.expires_at, revokedAt: row.revoked_at, status: sessionStatus(row) }
        : { id: row.id, user, createdAt: row.created_at, model: row.model, grounded: row.grounded, abstained: row.abstained };
    });
    return NextResponse.json({ items, total: count, page, pageSize }, { headers });
  } catch (error) {
    const response = jsonError(error);
    for (const [key, value] of Object.entries(headers)) response.headers.set(key, value);
    return response;
  }
}
