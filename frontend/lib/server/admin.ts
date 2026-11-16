import type { NextRequest } from "next/server";
import { ApiError } from "./api";
import { currentUser } from "./auth";
import { isAdminEmail } from "./admin-policy";

export async function requireAdmin(request: NextRequest) {
  const user = await currentUser(request);
  if (!isAdminEmail(user.email)) throw new ApiError(403, "Admin access is required");
  return user;
}
