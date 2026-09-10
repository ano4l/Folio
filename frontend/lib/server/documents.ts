import { supabaseAdmin } from "./supabase";

export async function seedDemoDocuments(userId: string) {
  if (process.env.FOLIO_SEED_DEMO_DOCUMENTS !== "true") return;
  const supabase = supabaseAdmin();
  const { count } = await supabase.from("vault_documents").select("id", { count: "exact", head: true }).eq("user_id", userId);
  if (count && count > 0) return;
  await supabase.from("vault_documents").insert([
    { user_id: userId, title: "Government Funding Award Letter — 2026", page_number: 1, status: "READY", content: "Award approved for R98,450 covering tuition, accommodation, and books. Maintain a 60% average, remain registered full-time, and submit proof of registration by 12 February 2026." },
    { user_id: userId, title: "Merit Bursary Agreement — 2026", page_number: 2, status: "READY", content: "The bursary is R32,000 per year. Renewal requires an official Semester 1 transcript showing an average above 75% and a signed renewal declaration before 02 August 2026." },
    { user_id: userId, title: "Semester 1 Fee Statement", page_number: 1, status: "READY", content: "Charges total R65,000: tuition R45,000, residence R12,000, and meals R8,000. A financial aid credit of R60,880 leaves R4,120 due by 28 February 2026." },
    { user_id: userId, title: "Standard Bank Account Confirmation", page_number: 1, status: "READY", content: "The active transactional account ending in 192 is verified for financial-aid disbursement deposits and has no restrictions." },
  ]);
}
