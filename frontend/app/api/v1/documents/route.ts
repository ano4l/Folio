import { NextRequest, NextResponse } from "next/server";
import { currentUser } from "@/lib/server/auth";
import { jsonError } from "@/lib/server/api";
import { supabaseAdmin } from "@/lib/server/supabase";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  try {
    const user = await currentUser(request);
    const { data, error } = await supabaseAdmin().from("vault_documents")
      .select("id,title,category,status,page_number,page_count,content,summary,entities,confidence,created_at")
      .eq("user_id", user.id).is("deleted_at", null).order("created_at", { ascending: false });
    if (error) throw new Error(`Unable to load documents: ${error.code}`);
    return NextResponse.json({ documents: (data || []).map(document => ({
      id: document.id,
      title: document.title,
      type: document.category,
      date: new Date(document.created_at).toLocaleDateString("en-ZA", { day: "2-digit", month: "short", year: "numeric" }),
      pages: document.page_count,
      status: mapStatus(document.status),
      confidence: document.confidence == null ? 0 : Math.round(Number(document.confidence) * 100),
      summary: document.summary || (document.status === "READY" ? "Document is ready." : "Stored securely. Extraction has not completed yet."),
      entities: Array.isArray(document.entities) ? document.entities : [],
      rawText: document.content || undefined,
    })) });
  } catch (error) { return jsonError(error); }
}

function mapStatus(status: string) {
  if (status === "READY") return "Ready";
  if (status === "FAILED") return "Error";
  if (["SCANNING", "OCR"].includes(status)) return "Scanning";
  if (["CLASSIFYING", "EXTRACTING", "INDEXING"].includes(status)) return "Analyzing";
  return "Uploading";
}
