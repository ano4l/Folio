export type AdminUser = {
  id: string;
  email: string;
  displayName: string;
  verified: boolean;
  createdAt: string;
  isAdmin: boolean;
};
export type AdminAccount = Pick<AdminUser, "id" | "email" | "displayName">;
export type AdminSession = {
  id: string;
  user: AdminAccount;
  createdAt: string;
  expiresAt: string;
  revokedAt: string | null;
  status: "Active" | "Expired" | "Revoked";
};
export type AdminUsage = {
  id: string;
  user: AdminAccount;
  createdAt: string;
  model: string | null;
  grounded: boolean;
  abstained: boolean;
};
export type AdminOverview = {
  totalUsers: number;
  verifiedUsers: number;
  activeSessions: number;
  sessionsLast30Days: number;
  recordedAiRequests: number;
  aiRequestsLast30Days: number;
};
export type AdminPageData<T> = {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
};
