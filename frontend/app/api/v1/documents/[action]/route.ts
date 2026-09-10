import { randomUUID } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { ApiError, jsonError, readJson, requireMutationHeader } from "@/lib/server/api";
import { currentUser } from "@/lib/server/auth";
import { supabaseAdmin } from "@/lib/server/supabase";
import { processDocument } from "@/lib/server/document-processing";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 60;
const BUCKET = "folio-documents";
const MAX_BYTES = 20 * 1024 * 1024;
const ALLOWED_TYPES = new Set(["application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "image/jpeg", "image/png"]);
type UploadRequest = { title?: string; category?: string; fileName?: string; mimeType?: string; byteSize?: number; documentId?: string };

export async function POST(request: NextRequest, { params }: { params: Promise<{ action: string }> }) {
  try {
    const { action } = await params;
    requireMutationHeader(request);
    const user = await currentUser(request);
    if (action === "upload-url") return uploadUrl(request, user.id);
    if (action === "complete") return complete(request, user.id);
    if (action === "process") return process(request, user.id);
    if (action === "restore") return restore(request, user.id);
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
    id: documentId, user_id: userId, title, category: body.category || "Fee Statement", original_name: originalName,
    storage_path: storagePath, mime_type: mimeType, byte_size: body.byteSize, status: "UPLOADING",
  });
  if (insertError) throw new Error(`Unable to create document: ${insertError.code}`);
  const { data, error } = await supabase.storage.from(BUCKET).createSignedUploadUrl(storagePath, { upsert: false });
  if (error || !data) {
    await supabase.from("vault_documents").delete().eq("id", documentId).eq("user_id", userId);
    throw new Error(`Unable to create secure upload: ${error?.message || "unknown"}`);
  }
  return NextResponse.json({ documentId, path: data.path, token: data.token, signedUrl: data.signedUrl });
}

async function complete(request: NextRequest, userId: string) {
  const body = await readJson<UploadRequest>(request);
  if (!body.documentId) throw new ApiError(400, "Document ID is required");
  const supabase = supabaseAdmin();
  const { data: document, error } = await supabase.from("vault_documents").select("id,storage_path,status")
    .eq("id", body.documentId).eq("user_id", userId).maybeSingle();
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
  const { data: document, error } = await supabaseAdmin().from("vault_documents").select("id,title,storage_path,mime_type,user_id,status").eq("id", body.documentId).eq("user_id", userId).maybeSingle();
  if (error || !document) throw new ApiError(404, "Document not found");
  const result = await processDocument(document);
  return NextResponse.json({ documentId: document.id, ...result });
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
