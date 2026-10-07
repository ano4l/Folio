import { randomUUID } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { ApiError, jsonError, readJson, requireMutationHeader } from "@/lib/server/api";
import { currentUser } from "@/lib/server/auth";
import { supabaseAdmin } from "@/lib/server/supabase";
import { processDocument } from "@/lib/server/document-processing";
import { validatePages } from "@/lib/server/document-pages";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 60;
const BUCKET = "folio-documents";
const MAX_BYTES = 20 * 1024 * 1024;
const ALLOWED_TYPES = new Set(["application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "image/jpeg", "image/png"]);
type UploadRequest = { title?: string; category?: string; fileName?: string; mimeType?: string; byteSize?: number; documentId?: string; extractedPages?: unknown };

export async function POST(request: NextRequest, { params }: { params: Promise<{ action: string }> }) {
  try {
    const { action } = await params;
    requireMutationHeader(request);
    const user = await currentUser(request);
    if (action === "upload-url") return await uploadUrl(request, user.id);
    if (action === "complete") return await complete(request, user.id);
    if (action === "process") return await process(request, user.id);
    if (action === "restore") return await restore(request, user.id);
    if (action === "source") return await source(request, user.id);
    throw new ApiError(404, "Not found");
  } catch (error) { return jsonError(error); }
}

export async function DELETE(request: NextRequest, { params }: { params: Promise<{ action: string }> }) {
  try {
    const { action } = await params;
    requireMutationHeader(request);
    const user = await currentUser(request);
    const { data, error } = await supabaseAdmin().from("vault_documents")
      .update({ deleted_at: new Date().toISOString(), updated_at: new Date().toISOString() })
      .eq("id", action).eq("user_id", user.id).is("deleted_at", null).select("id").maybeSingle();
    if (error) throw new Error(`Unable to move document to recycle bin: ${error.code}`);
    if (!data) throw new ApiError(404, "Document not found");
    return NextResponse.json({ documentId: data.id, deleted: true });
  } catch (error) { return jsonError(error); }
}

async function uploadUrl(request: NextRequest, userId: string) {
  const body = await readJson<UploadRequest>(request);
  const title = body.title?.trim(), originalName = body.fileName?.trim(), mimeType = body.mimeType;
  if (!title || title.length > 240) throw new ApiError(400, "Enter a document title");
  if (!originalName || originalName.length > 255) throw new ApiError(400, "Choose a valid file");
  if (!mimeType || !ALLOWED_TYPES.has(mimeType)) throw new ApiError(415, "Only PDF, DOCX, JPG, and PNG files are supported");
  if (!Number.isInteger(body.byteSize) || body.byteSize! < 1 || body.byteSize! > MAX_BYTES) throw new ApiError(413, "The document must be smaller than 20MB");
  const extension = extensionFor(mimeType), documentId = randomUUID(), storagePath = `${userId}/${documentId}/source.${extension}`;
  const supabase = supabaseAdmin();
  const { error: insertError } = await supabase.from("vault_documents").insert({
    id: documentId, user_id: userId, title, category: typeof body.category === "string" ? body.category.trim().slice(0, 80) || "Document" : "Document", original_name: originalName,
    storage_path: storagePath, mime_type: mimeType, byte_size: body.byteSize, status: "UPLOADING",
  });
  if (insertError?.code === "42P01" || insertError?.code === "PGRST205") throw new ApiError(503, "Folio database setup is incomplete. Apply the Supabase migration before uploading.");
  if (insertError) throw new Error(`Unable to create document: ${insertError.code}`);
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUploadUrl(storagePath, { upsert: false });
  if (error || !data) {
    await supabase.from("vault_documents").delete().eq("id", documentId).eq("user_id", userId);
    if (/bucket.*not found/i.test(error?.message || "")) throw new ApiError(503, "Secure storage is not ready. Create the folio-documents bucket by applying the Supabase migration.");
    throw new ApiError(503, "Secure storage could not prepare this upload. Check the Supabase URL, service key, and storage bucket.");
  }
  return NextResponse.json({ documentId, path: data.path, token: data.token, signedUrl: data.signedUrl });
}

async function complete(request: NextRequest, userId: string) {
  const body = await readJson<UploadRequest>(request);
  if (!body.documentId) throw new ApiError(400, "Document ID is required");
  const supabase = supabaseAdmin();
  const { data: document, error } = await supabase.from("vault_documents").select("id,storage_path,status")
    .eq("id", body.documentId).eq("user_id", userId).is("deleted_at", null).maybeSingle();
  if (error || !document) throw new ApiError(404, "Document not found");
  if (document.status !== "UPLOADING") return NextResponse.json({ documentId: document.id, status: document.status });
  const pathParts = String(document.storage_path).split("/"), fileName = pathParts.pop()!, directory = pathParts.join("/");
  const { data: objects, error: storageError } = await supabase.storage.from(BUCKET).list(directory, { search: fileName, limit: 10 });
  if (storageError || !objects?.some(object => object.name === fileName)) throw new ApiError(409, "Upload has not reached secure storage yet");
  const { error: updateError } = await supabase.from("vault_documents").update({ status: "UPLOADED", updated_at: new Date().toISOString() })
    .eq("id", document.id).eq("user_id", userId).eq("status", "UPLOADING");
  if (updateError) throw new Error(`Unable to complete upload: ${updateError.code}`);
  return NextResponse.json({ documentId: document.id, status: "UPLOADED" });
}

async function process(request: NextRequest, userId: string) {
  const body = await readJson<UploadRequest>(request);
  if (!body.documentId) throw new ApiError(400, "Document ID is required");
  const supabase = supabaseAdmin();
  const { data: document, error } = await supabase.from("vault_documents").select("id,title,storage_path,mime_type,user_id,status,content,updated_at").eq("id", body.documentId).eq("user_id", userId).is("deleted_at", null).maybeSingle();
  if (error || !document) throw new ApiError(404, "Document not found");
  if (document.status === "READY") return NextResponse.json({ documentId: document.id, status: "READY" });
  if (document.status === "UPLOADING") throw new ApiError(409, "Complete the upload before processing");
  if (["EXTRACTING", "CLASSIFYING"].includes(document.status) && Date.now() - Date.parse(document.updated_at) < 120_000) throw new ApiError(409, "This document is already being processed. Refresh shortly.");
  let pages;
  try { pages = validatePages(body.extractedPages); } catch { throw new ApiError(400, "Invalid or oversized extracted pages"); }
  const { data: claimed, error: claimError } = await supabase.from("vault_documents").update({ status: "EXTRACTING", updated_at: new Date().toISOString() })
    .eq("id", document.id).eq("user_id", userId).eq("updated_at", document.updated_at).is("deleted_at", null).select("id").maybeSingle();
  if (claimError || !claimed) throw new ApiError(409, "Document changed. Refresh and retry.");
  const result = await processDocument(document, pages);
  return NextResponse.json({ documentId: document.id, ...result });
}

async function source(request: NextRequest, userId: string) {
  const body = await readJson<UploadRequest>(request);
  if (!body.documentId) throw new ApiError(400, "Document ID is required");
  const supabase = supabaseAdmin();
  const { data, error } = await supabase.from("vault_documents").select("storage_path")
    .eq("id", body.documentId).eq("user_id", userId).is("deleted_at", null).maybeSingle();
  if (error || !data) throw new ApiError(404, "Document not found");
  const { data: signed, error: signingError } = await supabase.storage.from(BUCKET).createSignedUrl(data.storage_path, 120);
  if (signingError || !signed) throw new ApiError(503, "Original file is temporarily unavailable");
  return NextResponse.json({ url: signed.signedUrl }, { headers: { "Cache-Control": "no-store" } });
}

async function restore(request: NextRequest, userId: string) {
  const body = await readJson<UploadRequest>(request);
  if (!body.documentId) throw new ApiError(400, "Document ID is required");
  const { data, error } = await supabaseAdmin().from("vault_documents")
    .update({ deleted_at: null, updated_at: new Date().toISOString() })
    .eq("id", body.documentId).eq("user_id", userId).not("deleted_at", "is", null).select("id").maybeSingle();
  if (error) throw new Error(`Unable to restore document: ${error.code}`);
  if (!data) throw new ApiError(404, "Document not found in recycle bin");
  return NextResponse.json({ documentId: data.id, restored: true });
}

function extensionFor(mimeType: string) {
  if (mimeType === "application/pdf") return "pdf";
  if (mimeType.includes("wordprocessingml")) return "docx";
  return mimeType === "image/png" ? "png" : "jpg";
}
