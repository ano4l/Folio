import type { Metadata } from "next";
import FolioApp from "../../src/components/FolioApp";

export const metadata: Metadata = { title: "Administration — Folio", robots: { index: false, follow: false } };

export default function Admin() {
  return <FolioApp initialView="admin" />;
}
