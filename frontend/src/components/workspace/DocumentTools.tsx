import { useRef, useState } from "react";
import { PDFDocument, degrees } from "pdf-lib";
import {
  ArrowUp,
  ArrowDown,
  Trash2,
  Upload,
  Download,
  Share2,
  Camera,
  RotateCw,
  FilePlus2,
} from "lucide-react";
import { download, textPdf, pdfBlob } from "./exports";
import { ErrorNotice, IconButton, Modal } from "./ui";
type Mode = "merge" | "images" | "pages" | "rotate" | "text" | "docx";
export function reorder<T>(items: T[], from: number, to: number): T[] {
  const next = [...items];
  const [item] = next.splice(from, 1);
  next.splice(to, 0, item);
  return next;
}
export function validateFiles(files: File[], mode: Mode) {
  if (!files.length) throw new Error("Choose a file first.");
  if (
    files.some((f) => f.size > 20 * 1024 * 1024) ||
    files.reduce((sum, f) => sum + f.size, 0) > 20 * 1024 * 1024
  )
    throw new Error("Keep the total input size within 20 MB.");
  if (
    mode === "images" &&
    (files.length > 20 ||
      files.some((f) => !["image/jpeg", "image/png"].includes(f.type)))
  )
    throw new Error("Choose up to 20 JPEG or PNG images.");
}
export default function DocumentTools({
  onClose,
  upload,
}: {
  onClose: () => void;
  upload: (file: File, title: string) => void;
}) {
  const [mode, setMode] = useState<Mode>("merge"),
    [files, setFiles] = useState<File[]>([]),
    [pageOrder, setPageOrder] = useState<number[]>([]),
    [angle, setAngle] = useState(90),
    [text, setText] = useState(""),
    [title, setTitle] = useState("Prepared document"),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false),
    [result, setResult] = useState<File | null>(null);
  const camera = useRef<HTMLInputElement>(null);
  const add = async (incoming: File[]) => {
    setError("");
    setResult(null);
    try {
      const next =
        mode === "merge" || mode === "images"
          ? [...files, ...incoming]
          : incoming.slice(0, 1);
      validateFiles(next, mode);
      if (["pages", "rotate"].includes(mode)) {
        const pdf = await PDFDocument.load(await next[0].arrayBuffer());
        if (pdf.getPageCount() > 100)
          throw new Error("Choose a PDF with up to 100 pages.");
        setPageOrder(Array.from({ length: pdf.getPageCount() }, (_, i) => i));
      }
      setFiles(next);
    } catch (problem) {
      setError(
        problem instanceof Error
          ? problem.message
          : "Unable to read this file.",
      );
    }
  };
  const prepare = async () => {
    setBusy(true);
    setError("");
    setResult(null);
    try {
      if (mode !== "text") validateFiles(files, mode);
      let bytes: Uint8Array<ArrayBuffer>;
      if (mode === "text" || mode === "docx") {
        let content = text;
        if (mode === "docx") {
          const mammoth = await import("mammoth/mammoth.browser");
          content = (
            await mammoth.extractRawText({
              arrayBuffer: await files[0].arrayBuffer(),
            })
          ).value;
        }
        if (!content.trim()) throw new Error("No readable text found.");
        bytes = await textPdf(title.trim() || "Document", content);
      } else {
        const pdf = await PDFDocument.create();
        if (mode === "merge") {
          let total = 0;
          for (const file of files) {
            const source = await PDFDocument.load(await file.arrayBuffer());
            total += source.getPageCount();
            if (total > 100)
              throw new Error(
                "The merged PDF must contain no more than 100 pages.",
              );
            const pages = await pdf.copyPages(source, source.getPageIndices());
            pages.forEach((page) => pdf.addPage(page));
          }
        }
        if (mode === "images") {
          for (const file of files) {
            const buffer = await file.arrayBuffer(),
              image =
                file.type === "image/png"
                  ? await pdf.embedPng(buffer)
                  : await pdf.embedJpg(buffer);
            const page = pdf.addPage([595.28, 841.89]),
              scale = Math.min(499 / image.width, 745 / image.height);
            page.drawImage(image, {
              x: (595.28 - image.width * scale) / 2,
              y: (841.89 - image.height * scale) / 2,
              width: image.width * scale,
              height: image.height * scale,
            });
          }
        }
        if (mode === "pages" || mode === "rotate") {
          if (!pageOrder.length) throw new Error("Keep at least one page.");
          const source = await PDFDocument.load(await files[0].arrayBuffer());
          const copied = await pdf.copyPages(source, pageOrder);
          copied.forEach((page) => {
            if (mode === "rotate")
              page.setRotation(
                degrees((page.getRotation().angle + angle) % 360),
              );
            pdf.addPage(page);
          });
        }
        bytes = (await pdf.save()) as Uint8Array<ArrayBuffer>;
      }
      if (bytes.length > 20 * 1024 * 1024)
        throw new Error(
          "The result exceeds 20 MB. Remove some files or pages.",
        );
      const check = await PDFDocument.load(bytes);
      if (check.getPageCount() > 100)
        throw new Error(
          "The result exceeds 100 pages. Split the source into smaller sections.",
        );
      setResult(
        new File([bytes], `${title.trim() || "Prepared document"}.pdf`, {
          type: "application/pdf",
        }),
      );
    } catch (problem) {
      setError(
        problem instanceof Error
          ? problem.message
          : "This document could not be prepared.",
      );
    } finally {
      setBusy(false);
    }
  };
  const share = async () => {
    if (!result) return;
    try {
      if (navigator.canShare?.({ files: [result] }))
        await navigator.share({ files: [result], title });
      else download(result, result.name);
    } catch (problem) {
      if (!(problem instanceof DOMException && problem.name === "AbortError"))
        setError("Sharing is unavailable. Download the file instead.");
    }
  };
  const modes: [Mode, string][] = [
    ["merge", "Merge PDFs"],
    ["images", "Images to PDF"],
    ["pages", "Extract / reorder pages"],
    ["rotate", "Rotate PDF"],
    ["text", "Text to PDF"],
    ["docx", "DOCX to PDF"],
  ];
  return (
    <Modal title="Document tools" onClose={onClose} wide>
      <div className="ws-form">
        <label>
          Tool
          <select
            value={mode}
            onChange={(e) => {
              setMode(e.target.value as Mode);
              setFiles([]);
              setResult(null);
              setPageOrder([]);
              setError("");
            }}
          >
            {modes.map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <p className="ws-tool-limit">
          Up to 20 MB total, 100 PDF pages or 20 images. Files are prepared in
          this browser.
        </p>
        <label>
          Output title
          <input
            value={title}
            maxLength={120}
            onChange={(e) => {
              setTitle(e.target.value);
              setResult(null);
            }}
            required
          />
        </label>
        {mode === "text" ? (
          <label>
            Text
            <textarea
              rows={10}
              value={text}
              onChange={(e) => {
                setText(e.target.value);
                setResult(null);
              }}
              placeholder="Paste the text for your PDF"
            />
          </label>
        ) : (
          <>
            <label className="ws-file-picker">
              <Upload size={22} />
              <span>
                {mode === "images"
                  ? "Choose JPEG or PNG images"
                  : mode === "docx"
                    ? "Choose a DOCX file"
                    : "Choose PDF files"}
              </span>
              <input
                type="file"
                accept={
                  mode === "images"
                    ? "image/jpeg,image/png"
                    : mode === "docx"
                      ? ".docx"
                      : "application/pdf"
                }
                multiple={mode === "merge" || mode === "images"}
                onChange={(e) => {
                  void add(Array.from(e.target.files || []));
                  e.target.value = "";
                }}
              />
            </label>
            {mode === "images" && (
              <>
                <input
                  ref={camera}
                  type="file"
                  className="ws-hidden-input"
                  capture="environment"
                  accept="image/jpeg,image/png"
                  onChange={(e) => {
                    void add(Array.from(e.target.files || []));
                    e.target.value = "";
                  }}
                />
                <button
                  className="secondary"
                  onClick={() => {
                    camera.current?.click();
                  }}
                >
                  <Camera size={16} />
                  Use camera
                </button>
                <p>
                  Camera capture depends on your browser and device. Choose a
                  saved image if capture is unavailable.
                </p>
              </>
            )}
            <div className="ws-tool-files">
              {files.map((file, index) => (
                <div key={`${file.name}:${index}`}>
                  <span>
                    {index + 1}. {file.name}
                    <small>{(file.size / 1024 / 1024).toFixed(2)} MB</small>
                  </span>
                  <div className="ws-actions">
                    <IconButton
                      label="Move file up"
                      disabled={index === 0}
                      onClick={() => {
                        setFiles(reorder(files, index, index - 1));
                        setResult(null);
                      }}
                    >
                      <ArrowUp size={16} />
                    </IconButton>
                    <IconButton
                      label="Move file down"
                      disabled={index === files.length - 1}
                      onClick={() => {
                        setFiles(reorder(files, index, index + 1));
                        setResult(null);
                      }}
                    >
                      <ArrowDown size={16} />
                    </IconButton>
                    <IconButton
                      label="Remove file"
                      onClick={() => {
                        setFiles(files.filter((_, i) => i !== index));
                        setPageOrder([]);
                        setResult(null);
                      }}
                    >
                      <Trash2 size={16} />
                    </IconButton>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
        {(mode === "pages" || mode === "rotate") && pageOrder.length > 0 && (
          <fieldset className="ws-tool-pages">
            <legend>Output pages, in order</legend>
            {pageOrder.map((page, index) => (
              <div key={page}>
                <b>Page {page + 1}</b>
                <IconButton
                  label={`Move page ${page + 1} up`}
                  disabled={index === 0}
                  onClick={() => {
                    setPageOrder(reorder(pageOrder, index, index - 1));
                    setResult(null);
                  }}
                >
                  <ArrowUp size={15} />
                </IconButton>
                <IconButton
                  label={`Move page ${page + 1} down`}
                  disabled={index === pageOrder.length - 1}
                  onClick={() => {
                    setPageOrder(reorder(pageOrder, index, index + 1));
                    setResult(null);
                  }}
                >
                  <ArrowDown size={15} />
                </IconButton>
                <IconButton
                  label={`Remove page ${page + 1}`}
                  onClick={() => {
                    setPageOrder(pageOrder.filter((_, i) => i !== index));
                    setResult(null);
                  }}
                >
                  <Trash2 size={15} />
                </IconButton>
              </div>
            ))}
          </fieldset>
        )}
        {mode === "rotate" && (
          <label>
            Clockwise rotation
            <select
              value={angle}
              onChange={(e) => {
                setAngle(+e.target.value);
                setResult(null);
              }}
            >
              <option value={90}>90 degrees</option>
              <option value={180}>180 degrees</option>
              <option value={270}>270 degrees</option>
            </select>
          </label>
        )}
        {mode === "docx" && (
          <p>
            The PDF uses readable document text. Word layout, embedded images
            and tables are not reproduced.
          </p>
        )}
        <ErrorNotice message={error} />
        <div className="ws-form-actions">
          <button
            className="primary"
            disabled={busy || (mode === "text" ? !text.trim() : !files.length)}
            onClick={() => void prepare()}
          >
            <FilePlus2 size={16} />
            {busy ? "Preparing..." : "Prepare PDF"}
          </button>
        </div>
        {result && (
          <div className="ws-tool-result">
            <b>{result.name}</b>
            <p>{(result.size / 1024 / 1024).toFixed(2)} MB · Ready</p>
            <div className="ws-actions">
              <button
                className="secondary"
                onClick={() => download(result, result.name)}
              >
                <Download size={16} />
                Download
              </button>
              <IconButton
                label="Share prepared PDF"
                onClick={() => void share()}
              >
                <Share2 size={17} />
              </IconButton>
              <button
                className="primary"
                onClick={() => {
                  upload(result, title.trim() || "Prepared document");
                  onClose();
                }}
              >
                <Upload size={16} />
                Upload & analyse
              </button>
            </div>
          </div>
        )}
      </div>
    </Modal>
  );
}
