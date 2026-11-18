import type { Metadata } from "next";
import AdminDemo from "../../../src/components/admin/AdminDemo";

export const metadata: Metadata = { title: "Admin demo — Folio", robots: { index: false, follow: false } };

export default function Demo() {
  return <AdminDemo />;
}
