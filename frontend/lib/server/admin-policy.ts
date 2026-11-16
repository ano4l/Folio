/** Server configuration only. Never accept roles or allowlists from a client. */
export function isAdminEmail(email: string, allowlist = process.env.FOLIO_ADMIN_EMAILS || "") {
  const normalized = email.trim().toLowerCase();
  return !!normalized && allowlist.split(/[,;\n]/).some(value => value.trim().toLowerCase() === normalized);
}

export function sessionStatus(session: { revoked_at: string | null; expires_at: string }, now = Date.now()): "Active" | "Expired" | "Revoked" {
  if (session.revoked_at) return "Revoked";
  return new Date(session.expires_at).getTime() > now ? "Active" : "Expired";
}

export function parseAdminFilters(params: URLSearchParams) {
  const view = params.get("view") || "overview";
  if (!["overview", "users", "sessions", "usage"].includes(view)) throw new Error("Unknown admin view");
  const integer = (key: string, fallback: number, maximum: number) => {
    const raw = params.get(key);
    if (raw === null) return fallback;
    if (!/^[1-9]\d*$/.test(raw) || Number(raw) > maximum) throw new Error(`Invalid ${key}`);
    return Number(raw);
  };
  const page = integer("page", 1, 100000), pageSize = integer("pageSize", 25, 100);
  const userId = params.get("userId") || "";
  if (userId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(userId)) throw new Error("Invalid user filter");
  const days = params.get("days") || "30";
  if (!["7", "30", "90", "all"].includes(days)) throw new Error("Invalid date filter");
  // Permit ordinary names/email characters, excluding PostgREST filter syntax and wildcards.
  const search = (params.get("search") || "").trim();
  if (search.length > 120 || /[^\p{L}\p{M}\p{N}\s@.'+_\-]/u.test(search)) throw new Error("Search using a name or email address");
  return { view, page, pageSize, userId, days, search };
}
