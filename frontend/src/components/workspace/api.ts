import { createClient } from "@supabase/supabase-js";
import type { VaultDocument } from "./models";
export const API_URL = (process.env.NEXT_PUBLIC_API_URL || "/api").replace(
  /\/$/,
  "",
);
export async function api<T>(
  path: string,
  body?: unknown,
  signal?: AbortSignal,
  method = body === undefined ? "GET" : "POST",
): Promise<T> {
  const response = await fetch(`${API_URL}/v1/${path}`, {
    method,
    credentials: "include",
    signal,
    headers: {
      "Content-Type": "application/json",
      "X-Requested-With": "FolioWeb",
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok)
    throw new Error(data.message || `Request failed (${response.status})`);
  return data as T;
}
export const listDocuments = async (signal?: AbortSignal) =>
  (
    await api<{ documents: VaultDocument[] }>("documents", undefined, signal)
  ).documents.map((d) => ({
    ...d,
    id: String(d.id),
    entities: d.entities || [],
  }));
const pause = (ms: number, signal: AbortSignal) =>
  new Promise<void>((resolve, reject) => {
    if (signal.aborted) {
      reject(new DOMException("Cancelled", "AbortError"));
      return;
    }
    const cancelled = () => {
      clearTimeout(timer);
      reject(new DOMException("Cancelled", "AbortError"));
    };
    const timer = setTimeout(() => {
      signal.removeEventListener("abort", cancelled);
      resolve();
    }, ms);
    signal.addEventListener("abort", cancelled, { once: true });
  });
export async function recoverProcessing(
  documentId: string,
  signal: AbortSignal,
  onStage: (stage: string) => void,
) {
  for (let attempt = 0; attempt < 3; attempt++) {
    signal.throwIfAborted();
    onStage(attempt ? "Retrying summary" : "Reading and summarising");
    let result: { status: string } | undefined;
    try {
      result = await api("documents/process", { documentId }, signal);
    } catch (error) {
      if (signal.aborted) throw error;
    }
    if (result?.status === "READY") return "Ready";
    let snapshot = (await listDocuments(signal)).find(
      (d) => d.id === documentId,
    );
    for (
      let poll = 0;
      snapshot &&
      ["Scanning", "Analyzing"].includes(snapshot.status) &&
      poll < 25;
      poll++
    ) {
      onStage("Saved securely. Finishing summary");
      await pause(5000, signal);
      snapshot = (await listDocuments(signal)).find((d) => d.id === documentId);
    }
    if (snapshot?.status === "Ready") return "Ready";
    if (
      snapshot?.status === "Needs review" &&
      !snapshot.summary
        .toLowerCase()
        .includes("ai summarisation is temporarily unavailable")
    )
      return "Needs review";
    if (attempt < 2) {
      onStage("Saved securely. Waiting to retry summary");
      await pause(attempt ? 90000 : 30000, signal);
    }
  }
  return "Awaiting processing";
}
export async function uploadDocument(
  file: File,
  title: string,
  category: string,
  signal: AbortSignal,
  onStage: (stage: string) => void,
  onStored: (id: string) => void,
) {
  if (file.size > 20 * 1024 * 1024)
    throw new Error("Choose a file up to 20 MB.");
  if (file.type === "application/pdf") {
    const { PDFDocument } = await import("pdf-lib");
    const pdf = await PDFDocument.load(await file.arrayBuffer());
    if (pdf.getPageCount() > 100)
      throw new Error("Choose a PDF with up to 100 pages.");
  }
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL,
    key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("Document storage is not configured.");
  onStage("Preparing secure upload");
  const upload = await api<{ documentId: string; path: string; token: string }>(
    "documents/upload-url",
    {
      title,
      category,
      fileName: file.name,
      mimeType: file.type,
      byteSize: file.size,
    },
    signal,
  );
  signal.throwIfAborted();
  onStage("Uploading original");
  const client = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await client.storage
    .from("folio-documents")
    .uploadToSignedUrl(upload.path, upload.token, file, {
      contentType: file.type,
      upsert: false,
    });
  signal.throwIfAborted();
  if (error) throw new Error(error.message);
  await api("documents/complete", { documentId: upload.documentId }, signal);
  signal.throwIfAborted();
  onStored(upload.documentId);
  await recoverProcessing(upload.documentId, signal, onStage);
  return upload.documentId;
}
