import { useEffect, useRef, useState } from "react";
// @ts-ignore Node's native test runner uses explicit TypeScript extensions.
import { emptyWorkspace, type WorkspaceData } from "./models.ts";

type RecordData = { key: CryptoKey; iv?: Uint8Array; ciphertext?: ArrayBuffer };
const database = () =>
  new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open("folio-browser-workspace", 1);
    request.onupgradeneeded = () =>
      request.result.createObjectStore("accounts");
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
async function readRecord(account: string): Promise<RecordData | undefined> {
  const db = await database();
  try {
    return await new Promise((resolve, reject) => {
      const request = db
        .transaction("accounts")
        .objectStore("accounts")
        .get(account);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  } finally {
    db.close();
  }
}
async function writeRecord(account: string, data: RecordData) {
  const db = await database();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction("accounts", "readwrite");
      tx.objectStore("accounts").put(data, account);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error);
    });
  } finally {
    db.close();
  }
}
async function createRecord(
  account: string,
  key: CryptoKey,
): Promise<RecordData> {
  const db = await database();
  try {
    return await new Promise((resolve, reject) => {
      const tx = db.transaction("accounts", "readwrite"),
        records = tx.objectStore("accounts"),
        request = records.get(account);
      let result: RecordData;
      request.onsuccess = () => {
        result = request.result || { key };
        if (!request.result) records.put(result, account);
      };
      tx.oncomplete = () => resolve(result);
      tx.onerror = () => reject(tx.error);
      tx.onabort = () => reject(tx.error);
    });
  } finally {
    db.close();
  }
}
export async function encryptWorkspace(
  account: string,
  key: CryptoKey,
  data: WorkspaceData,
): Promise<RecordData> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: new TextEncoder().encode(account) },
    key,
    new TextEncoder().encode(JSON.stringify(data)),
  );
  return { key, iv, ciphertext };
}
export async function decryptWorkspace(
  account: string,
  record: RecordData,
): Promise<WorkspaceData> {
  if (!record.iv || !record.ciphertext) return emptyWorkspace();
  const plaintext = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: record.iv as Uint8Array<ArrayBuffer>,
      additionalData: new TextEncoder().encode(account),
    },
    record.key,
    record.ciphertext,
  );
  const parsed = JSON.parse(new TextDecoder().decode(plaintext));
  return {
    ...emptyWorkspace(),
    ...parsed,
    activity: (parsed.activity || []).slice(0, 300),
  };
}
export function useWorkspaceData(account: string) {
  const [data, setData] = useState<WorkspaceData>(emptyWorkspace);
  const [ready, setReady] = useState(false);
  const [error, setError] = useState("");
  const keyRef = useRef<CryptoKey | null>(null);
  const queue = useRef(Promise.resolve());
  const generation = useRef(0);
  useEffect(() => {
    const current = ++generation.current;
    setReady(false);
    setData(emptyWorkspace());
    keyRef.current = null;
    void (async () => {
      try {
        if (!crypto.subtle)
          throw new Error("Browser storage requires a secure connection.");
        let record = await readRecord(account);
        if (!record)
          record = await createRecord(
            account,
            await crypto.subtle.generateKey(
              { name: "AES-GCM", length: 256 },
              false,
              ["encrypt", "decrypt"],
            ),
          );
        const key = record.key;
        const restored = await decryptWorkspace(account, record);
        if (generation.current !== current) return;
        keyRef.current = key;
        setData(restored);
        setReady(true);
      } catch (problem) {
        if (generation.current === current)
          setError(
            problem instanceof Error
              ? problem.message
              : "Unable to open browser workspace.",
          );
      }
    })();
    return () => {
      generation.current++;
      keyRef.current = null;
    };
  }, [account]);
  useEffect(() => {
    const key = keyRef.current;
    if (!ready || !key) return;
    // Serialize snapshots so a slow encryption cannot overwrite a later edit.
    queue.current = queue.current
      .catch(() => undefined)
      .then(async () => {
        await writeRecord(account, await encryptWorkspace(account, key, data));
      })
      .catch((problem) =>
        setError(
          problem instanceof Error
            ? problem.message
            : "Unable to save browser workspace.",
        ),
      );
  }, [account, data, ready]);
  const update = (edit: (previous: WorkspaceData) => WorkspaceData) => {
    if (ready) setData(edit);
  };
  const flush = () => queue.current;
  return { data, update, ready, error, flush };
}
