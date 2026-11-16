import { useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  Search,
  ChevronLeft,
  ChevronRight,
  Download,
  ExternalLink,
  MessageSquareText,
  Bookmark,
  Minus,
  Plus,
  FileText,
} from "lucide-react";
import { api } from "./api";
import { sourcePages, type VaultDocument } from "./models";
import { download, pdfBlob, textPdf } from "./exports";
import { ErrorNotice, IconButton, PageHeader } from "./ui";
import type { NoteSeed } from "./StudyView";
type Props = {
  doc: VaultDocument;
  initialPage: number | null;
  onBack: () => void;
  ask: (question: string) => void;
  saveNote: (seed: NoteSeed) => void;
  toast: (message: string) => void;
};
export default function DocumentReader({
  doc,
  initialPage,
  onBack,
  ask,
  saveNote,
}: Props) {
  const pages = useMemo(() => sourcePages(doc), [doc]);
  const [pageIndex, setPageIndex] = useState(
      Math.max(
        0,
        pages.findIndex((p) => p.page === initialPage),
      ),
    ),
    [size, setSize] = useState(16),
    [query, setQuery] = useState(""),
    [matchIndex, setMatchIndex] = useState(0),
    [selection, setSelection] = useState(""),
    [tab, setTab] = useState<"text" | "original" | "summary">("text"),
    [url, setUrl] = useState(""),
    [loading, setLoading] = useState(false),
    [error, setError] = useState("");
  const page = pages[pageIndex] || pages[0];
  const matches = useMemo(() => {
    if (!query.trim()) return [];
    const needle = query.toLowerCase();
    return pages.flatMap((p, index) => {
      const found: { page: number; offset: number }[] = [];
      const content = p.text.toLowerCase();
      let offset = content.indexOf(needle);
      while (offset >= 0) {
        found.push({ page: index, offset });
        offset = content.indexOf(needle, offset + needle.length);
      }
      return found;
    });
  }, [query, pages]);
  useEffect(() => {
    setMatchIndex(0);
    if (matches.length) setPageIndex(matches[0].page);
  }, [query, matches]);
  useEffect(() => {
    document
      .getElementById(`reader-match-${matchIndex}`)
      ?.scrollIntoView({ block: "center", behavior: "smooth" });
  }, [matchIndex, pageIndex]);
  const navigateMatch = (offset: number) => {
    if (!matches.length) return;
    const next = (matchIndex + offset + matches.length) % matches.length;
    setMatchIndex(next);
    setPageIndex(matches[next].page);
  };
  const original = async () => {
    setLoading(true);
    setError("");
    try {
      const result = await api<{ url: string }>("documents/source", {
        documentId: doc.id,
      });
      setUrl(result.url);
      setTab("original");
    } catch (problem) {
      setError(
        problem instanceof Error ? problem.message : "Original unavailable.",
      );
    } finally {
      setLoading(false);
    }
  };
  const exportPdf = async () => {
    try {
      download(
        pdfBlob(
          await textPdf(
            doc.title,
            pages
              .map(
                (p) =>
                  `${p.page ? `Page ${p.page}` : "Page unavailable"}\n\n${p.text}`,
              )
              .join("\n\n"),
          ),
        ),
        `${doc.title} readable.pdf`,
      );
    } catch (problem) {
      setError(
        problem instanceof Error ? problem.message : "PDF export failed.",
      );
    }
  };
  const renderText = () => {
    if (!query || !matches.length) return page.text;
    const output = [];
    let offset = 0;
    const needle = query.toLowerCase();
    for (
      let at = page.text.toLowerCase().indexOf(needle);
      at >= 0;
      at = page.text.toLowerCase().indexOf(needle, offset)
    ) {
      output.push(page.text.slice(offset, at));
      const globalIndex = matches.findIndex(
        (m) => m.page === pageIndex && m.offset === at,
      );
      output.push(
        <mark
          id={`reader-match-${globalIndex}`}
          className={globalIndex === matchIndex ? "active" : ""}
          key={at}
        >
          {page.text.slice(at, at + needle.length)}
        </mark>,
      );
      offset = at + needle.length;
    }
    output.push(page.text.slice(offset));
    return output;
  };
  return (
    <section className="ws-view ws-reader">
      <PageHeader title={doc.title} subtitle={`${doc.type} · ${doc.status}`}>
        <IconButton label="Back to documents" onClick={onBack}>
          <ArrowLeft size={18} />
        </IconButton>
        <button
          className="secondary"
          onClick={() => void original()}
          disabled={loading}
        >
          <ExternalLink size={15} />
          {loading ? "Opening..." : "Original"}
        </button>
        <IconButton
          label="Download extracted text"
          onClick={() =>
            download(
              new Blob(
                [
                  pages
                    .map(
                      (p) => `${p.page ? `Page ${p.page}\n\n` : ""}${p.text}`,
                    )
                    .join("\n\n"),
                ],
                { type: "text/plain" },
              ),
              `${doc.title}.txt`,
            )
          }
        >
          <Download size={18} />
        </IconButton>
        <button className="secondary" onClick={() => void exportPdf()}>
          <FileText size={15} />
          Readable PDF
        </button>
      </PageHeader>
      <ErrorNotice message={error} />
      <div className="ws-tabs" role="tablist" aria-label="Document views">
        {(
          [
            ["text", "Read"],
            ["summary", "Summary"],
            ["original", "Original"],
          ] as const
        ).map(([key, title]) => (
          <button
            role="tab"
            aria-selected={tab === key}
            className={tab === key ? "active" : ""}
            key={key}
            onClick={() =>
              key === "original" && !url ? void original() : setTab(key)
            }
          >
            {title}
          </button>
        ))}
      </div>
      {tab === "text" && (
        <>
          <div className="ws-reader-toolbar">
            <label className="ws-reader-search">
              <Search size={16} />
              <input
                aria-label="Search document text"
                placeholder="Find in document"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
              />
            </label>
            {query && (
              <>
                <small>
                  {matches.length
                    ? `${matchIndex + 1} of ${matches.length}`
                    : "No matches"}
                </small>
                <IconButton
                  label="Previous match"
                  onClick={() => navigateMatch(-1)}
                  disabled={!matches.length}
                >
                  <ChevronLeft size={17} />
                </IconButton>
                <IconButton
                  label="Next match"
                  onClick={() => navigateMatch(1)}
                  disabled={!matches.length}
                >
                  <ChevronRight size={17} />
                </IconButton>
              </>
            )}
            <label>
              Page
              <select
                value={pageIndex}
                onChange={(e) => {
                  setPageIndex(+e.target.value);
                  setSelection("");
                }}
              >
                {pages.map((p, index) => (
                  <option key={index} value={index}>
                    {p.page ? p.page : "Unavailable"}
                  </option>
                ))}
              </select>
            </label>
            <IconButton
              label="Smaller reading text"
              disabled={size <= 12}
              onClick={() => setSize((value) => value - 2)}
            >
              <Minus size={16} />
            </IconButton>
            <IconButton
              label="Larger reading text"
              disabled={size >= 24}
              onClick={() => setSize((value) => value + 2)}
            >
              <Plus size={16} />
            </IconButton>
          </div>
          <div
            className="ws-document-text"
            style={{ fontSize: size }}
            onMouseUp={() =>
              setSelection(
                window.getSelection()?.toString().trim().slice(0, 12000) || "",
              )
            }
            onTouchEnd={() =>
              setTimeout(
                () =>
                  setSelection(
                    window.getSelection()?.toString().trim().slice(0, 12000) ||
                      "",
                  ),
                100,
              )
            }
          >
            <small className="ws-page-label">
              {page.page
                ? `Source page ${page.page}`
                : "Source page unavailable"}
            </small>
            {page.text ? (
              <div>{renderText()}</div>
            ) : (
              <p>
                No extracted text is available. Open the original or retry
                processing in the vault.
              </p>
            )}
          </div>
          {selection && (
            <div className="ws-selection-bar">
              <span>{selection.length} characters selected</span>
              <button
                className="primary"
                onClick={() =>
                  ask(`Explain this passage from my document:\n\n${selection}`)
                }
              >
                <MessageSquareText size={15} />
                Ask
              </button>
              <button
                className="secondary"
                onClick={() =>
                  saveNote({
                    text: selection,
                    documentId: doc.id,
                    documentTitle: doc.title,
                    sourcePage: page.page,
                  })
                }
              >
                <Bookmark size={15} />
                Save note
              </button>
            </div>
          )}
          <div className="ws-reader-footer">
            <IconButton
              label="Previous source page"
              disabled={pageIndex === 0}
              onClick={() => {
                setPageIndex((i) => i - 1);
                setSelection("");
              }}
            >
              <ChevronLeft size={18} />
            </IconButton>
            <span>{page.page ? `Page ${page.page}` : "Page unavailable"}</span>
            <IconButton
              label="Next source page"
              disabled={pageIndex >= pages.length - 1}
              onClick={() => {
                setPageIndex((i) => i + 1);
                setSelection("");
              }}
            >
              <ChevronRight size={18} />
            </IconButton>
          </div>
        </>
      )}
      {tab === "summary" && (
        <div className="ws-document-summary">
          <h2>Document summary</h2>
          <p className="ws-note-text">
            {doc.summary || "A summary is not available yet."}
          </p>
          {doc.entities.length > 0 && (
            <>
              <h3>Extracted details</h3>
              <dl>
                {doc.entities.map((entity, index) => (
                  <div key={index}>
                    <dt>{entity.label}</dt>
                    <dd>{entity.value}</dd>
                  </div>
                ))}
              </dl>
            </>
          )}
        </div>
      )}
      {tab === "original" && url && (
        <div className="ws-original">
          <p>
            <a href={url} target="_blank" rel="noopener noreferrer">
              <ExternalLink size={15} />
              Open or download original
            </a>
          </p>
          <iframe
            title={`Original file: ${doc.title}`}
            src={url}
            sandbox="allow-scripts allow-same-origin"
          />
        </div>
      )}
    </section>
  );
}
