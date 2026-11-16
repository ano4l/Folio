import { useMemo, useState } from "react";
import {
  BookOpen,
  Plus,
  Pencil,
  Trash2,
  ArrowLeft,
  ArrowRight,
  Upload,
  MessageSquareText,
  Download,
  Layers3,
  CalendarDays,
  Check,
  RotateCcw,
} from "lucide-react";
import {
  newId,
  sourcePages,
  dueCards,
  quizProgress,
  reviewCard,
  today,
  shiftDate,
  type WorkspaceData,
  type VaultDocument,
  type Space,
  type Note,
  type Card,
  type Task,
} from "./models";
import { download, textPdf, pdfBlob, studyMarkdown } from "./exports";
import { Empty, ErrorNotice, IconButton, Modal, PageHeader } from "./ui";

export type Update = (edit: (data: WorkspaceData) => WorkspaceData) => void;
export type NoteSeed = {
  text: string;
  documentId: string;
  documentTitle: string;
  sourcePage: number | null;
  spaceId?: string;
};
type Props = {
  data: WorkspaceData;
  update: Update;
  documents: VaultDocument[];
  selectedSpace: string | null;
  selectSpace: (id: string | null) => void;
  openDocument: (id: string, page?: number | null) => void;
  openChat: (id: string, spaceId?: string) => void;
  upload: (spaceId?: string) => void;
  sample: (spaceId: string) => void;
  toast: (text: string) => void;
  undo: (label: string, restore: () => void) => void;
  openTasks: () => void;
};
export function NoteEditor({
  data,
  documents,
  update,
  seed,
  note,
  onClose,
  toast,
}: {
  data: WorkspaceData;
  documents: VaultDocument[];
  update: Update;
  seed?: NoteSeed;
  note?: Note;
  onClose: () => void;
  toast: (message: string) => void;
}) {
  const [title, setTitle] = useState(note?.title || ""),
    [text, setText] = useState(note?.text || seed?.text || "");
  const [spaceId, setSpaceId] = useState(
    note?.spaceId ||
      seed?.spaceId ||
      data.spaces.find((s) => s.documentIds.includes(seed?.documentId || ""))
        ?.id ||
      data.spaces[0]?.id ||
      "",
  );
  const [documentId, setDocumentId] = useState(
    note?.documentId || seed?.documentId || "",
  );
  const [newSpace, setNewSpace] = useState("");
  const save = (event: React.FormEvent) => {
    event.preventDefault();
    let targetSpace = spaceId;
    const doc = documents.find((d) => d.id === documentId);
    if (!targetSpace && !newSpace.trim()) return;
    if (!targetSpace) targetSpace = newId();
    const entry: Note = {
      id: note?.id || newId(),
      spaceId: targetSpace,
      title: title.trim(),
      text: text.trim(),
      documentId,
      documentTitle:
        doc?.title ||
        seed?.documentTitle ||
        note?.documentTitle ||
        "Personal note",
      sourcePage:
        documentId === (note?.documentId || seed?.documentId)
          ? (note?.sourcePage ?? seed?.sourcePage ?? null)
          : null,
      createdAt: note?.createdAt || new Date().toISOString(),
    };
    update((previous) => ({
      ...previous,
      spaces: spaceId
        ? previous.spaces
        : [
            ...previous.spaces,
            {
              id: targetSpace,
              name: newSpace.trim(),
              documentIds: documentId ? [documentId] : [],
              createdAt: entry.createdAt,
            },
          ],
      notes: note
        ? previous.notes.map((n) => (n.id === note.id ? entry : n))
        : [entry, ...previous.notes],
    }));
    toast(note ? "Note updated." : "Note saved in Study.");
    onClose();
  };
  return (
    <Modal title={note ? "Edit note" : "Save a study note"} onClose={onClose}>
      <form className="ws-form" onSubmit={save}>
        <label>
          Title
          <input
            required
            maxLength={160}
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="A concept to remember"
          />
        </label>
        <label>
          Course
          <select value={spaceId} onChange={(e) => setSpaceId(e.target.value)}>
            <option value="">Create a course</option>
            {data.spaces.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        </label>
        {!spaceId && (
          <label>
            New course name
            <input
              required
              maxLength={120}
              value={newSpace}
              onChange={(e) => setNewSpace(e.target.value)}
            />
          </label>
        )}
        <label>
          Source
          <select
            value={documentId}
            onChange={(e) => setDocumentId(e.target.value)}
          >
            <option value="">Personal note</option>
            {documents.map((d) => (
              <option key={d.id} value={d.id}>
                {d.title}
              </option>
            ))}
          </select>
        </label>
        <label>
          Note
          <textarea
            required
            value={text}
            onChange={(e) => setText(e.target.value)}
            rows={8}
          />
        </label>
        {(note?.sourcePage || seed?.sourcePage) && (
          <p>Source page {note?.sourcePage || seed?.sourcePage}</p>
        )}
        <div className="ws-form-actions">
          <button type="button" className="secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="primary" type="submit">
            <Check size={16} />
            Save note
          </button>
        </div>
      </form>
    </Modal>
  );
}
export default function StudyView({
  data,
  update,
  documents,
  selectedSpace,
  selectSpace,
  openDocument,
  openChat,
  upload,
  sample,
  toast,
  undo,
  openTasks,
}: Props) {
  const [tab, setTab] = useState<"sources" | "notes" | "revision">("sources");
  const [editSpace, setEditSpace] = useState<Space | "new" | null>(null),
    [spaceName, setSpaceName] = useState("");
  const [attach, setAttach] = useState(false),
    [attachIds, setAttachIds] = useState<string[]>([]);
  const [noteEdit, setNoteEdit] = useState<Note | "new" | null>(null),
    [search, setSearch] = useState("");
  const [review, setReview] = useState<string[] | null>(null),
    [revealed, setRevealed] = useState(false),
    [reviewed, setReviewed] = useState(0);
  const [exam, setExam] = useState(false),
    [examDate, setExamDate] = useState(shiftDate(today(), 14));
  const [confirmDelete, setConfirmDelete] = useState(false),
    [error, setError] = useState("");
  const [cardEdit, setCardEdit] = useState<Card | null>(null),
    [front, setFront] = useState(""),
    [back, setBack] = useState("");
  const space = data.spaces.find((s) => s.id === selectedSpace);
  const docs = documents.filter((d) => space?.documentIds.includes(d.id));
  const notes = data.notes.filter(
    (n) =>
      n.spaceId === selectedSpace &&
      `${n.title} ${n.text}`.toLowerCase().includes(search.toLowerCase()),
  );
  const cards = data.cards.filter((c) => c.spaceId === selectedSpace),
    due = dueCards(cards);
  const progress = quizProgress(
    Object.values(data.quizzes).filter((q) => q.spaceId === selectedSpace),
  );
  const activeCard = review?.length
    ? cards.find((c) => c.id === review[0])
    : undefined;
  const plan = useMemo(() => {
    if (!space || !examDate) return [];
    const days = Math.round(
      (Date.parse(`${examDate}T12:00:00Z`) -
        Date.parse(`${today()}T12:00:00Z`)) /
        86400000,
    );
    if (days < 1) return [];
    const offsets = [
      ...new Set([
        Math.floor(days * 0.25),
        Math.floor(days * 0.5),
        Math.floor(days * 0.8),
      ]),
    ];
    return [
      ...offsets.map((offset, i) => ({
        title: `${["Read & make notes", "Practise questions", "Review weak concepts"][i]} · ${space.name}`,
        due: shiftDate(today(), offset),
      })),
      { title: `Exam · ${space.name}`, due: examDate },
    ];
  }, [space, examDate]);
  const exportNotes = async (format: "md" | "pdf") => {
    if (!space) return;
    try {
      const text = studyMarkdown(
        space.name,
        data.notes.filter((n) => n.spaceId === space.id),
        cards,
      );
      download(
        format === "pdf"
          ? pdfBlob(await textPdf(space.name, text))
          : new Blob([text], { type: "text/markdown" }),
        `${space.name}.${format}`,
      );
    } catch (problem) {
      setError(problem instanceof Error ? problem.message : "Export failed.");
    }
  };
  const createCard = (note: Note) => {
    const card: Card = {
      id: newId(),
      spaceId: note.spaceId,
      front: note.title,
      back: note.text,
      documentId: note.documentId,
      documentTitle: note.documentTitle,
      sourcePage: note.sourcePage,
      sourceExcerpt: "",
      dueAt: "",
      reviews: 0,
      intervalDays: 0,
    };
    update((p) => ({ ...p, cards: [...p.cards, card] }));
    toast("Revision card added.");
  };
  const rate = (recalled: boolean) => {
    if (!activeCard || !revealed) return;
    const next = reviewCard(activeCard, recalled);
    update((p) => ({
      ...p,
      cards: p.cards.map((c) => (c.id === next.id ? next : c)),
    }));
    setReview(review!.slice(1));
    setReviewed((count) => count + 1);
    setRevealed(false);
  };
  return (
    <section className="ws-view">
      <PageHeader
        title={space ? space.name : "Study"}
        subtitle={
          space
            ? `${docs.length} sources · ${progress.answered} answers recorded${progress.answered ? ` · ${Math.round((progress.correct / progress.answered) * 100)}% correct` : ""}`
            : "Your courses, notes and revision."
        }
      >
        {space ? (
          <>
            <IconButton
              label="Back to courses"
              onClick={() => {
                selectSpace(null);
                setReview(null);
              }}
            >
              <ArrowLeft size={18} />
            </IconButton>
            <IconButton
              label="Rename course"
              onClick={() => {
                setEditSpace(space);
                setSpaceName(space.name);
              }}
            >
              <Pencil size={17} />
            </IconButton>
            <IconButton
              label="Delete course"
              onClick={() => setConfirmDelete(true)}
            >
              <Trash2 size={17} />
            </IconButton>
          </>
        ) : (
          <button
            className="primary"
            onClick={() => {
              setEditSpace("new");
              setSpaceName("");
            }}
          >
            <Plus size={16} />
            New course
          </button>
        )}
      </PageHeader>
      <ErrorNotice message={error} />
      {!space ? (
        <>
          {data.spaces.length === 0 ? (
            <Empty
              title="Make space for your next course"
              action={
                <button
                  className="primary"
                  onClick={() => {
                    setEditSpace("new");
                    setSpaceName("");
                  }}
                >
                  <Plus size={16} />
                  Create a course
                </button>
              }
            >
              Keep your lecture sources, linked notes and revision together.
            </Empty>
          ) : (
            <div className="ws-course-list">
              {data.spaces.map((item) => {
                const count = data.notes.filter(
                    (n) => n.spaceId === item.id,
                  ).length,
                  dueCount = dueCards(
                    data.cards.filter((c) => c.spaceId === item.id),
                  ).length;
                const p = quizProgress(
                  Object.values(data.quizzes).filter(
                    (q) => q.spaceId === item.id,
                  ),
                );
                return (
                  <button
                    className="ws-course"
                    key={item.id}
                    onClick={() => {
                      selectSpace(item.id);
                      setTab("sources");
                      setSearch("");
                    }}
                  >
                    <span className="ws-course-icon">
                      <BookOpen size={22} />
                    </span>
                    <span>
                      <b>{item.name}</b>
                      <small>
                        {
                          item.documentIds.filter((id) =>
                            documents.some((d) => d.id === id),
                          ).length
                        }{" "}
                        sources · {count} notes · {dueCount} cards due
                      </small>
                      {p.answered > 0 && (
                        <small>
                          {p.correct}/{p.answered} quiz answers correct
                        </small>
                      )}
                    </span>
                    <ArrowRight size={19} />
                  </button>
                );
              })}
            </div>
          )}
        </>
      ) : (
        <>
          <div className="ws-tabs" role="tablist" aria-label="Course views">
            {(
              [
                ["sources", "Sources"],
                ["notes", "Notes"],
                ["revision", "Revision"],
              ] as const
            ).map(([key, label]) => (
              <button
                key={key}
                role="tab"
                aria-selected={tab === key}
                className={tab === key ? "active" : ""}
                onClick={() => {
                  setTab(key);
                  setReview(null);
                }}
              >
                {label}
                {key === "revision" && due.length > 0 ? ` (${due.length})` : ""}
              </button>
            ))}
          </div>
          {tab === "sources" && (
            <>
              <div className="ws-toolbar">
                <button
                  className="primary"
                  onClick={() => {
                    setAttach(true);
                    setAttachIds(space.documentIds);
                  }}
                >
                  <Plus size={16} />
                  Add vault sources
                </button>
                <button className="secondary" onClick={() => upload(space.id)}>
                  <Upload size={16} />
                  Upload material
                </button>
                <button className="secondary" onClick={() => sample(space.id)}>
                  <FileSample />
                  Sample lecture
                </button>
              </div>
              {docs.length ? (
                <div className="ws-source-list">
                  {docs.map((doc) => (
                    <article className="ws-source" key={doc.id}>
                      <div>
                        <span className="ws-category">{doc.type}</span>
                        <h3>{doc.title}</h3>
                        <p>
                          {doc.pages > 0
                            ? `${doc.pages} pages`
                            : "Pages unavailable"}{" "}
                          · {doc.status}
                        </p>
                        <p className="ws-clamp">
                          {doc.summary ||
                            sourcePages(doc)[0]?.text.slice(0, 180)}
                        </p>
                      </div>
                      <div className="ws-actions">
                        <button
                          className="secondary"
                          onClick={() => openDocument(doc.id)}
                        >
                          <BookOpen size={15} />
                          Read
                        </button>
                        <button
                          className="primary"
                          disabled={doc.status !== "Ready"}
                          onClick={() => openChat(doc.id, space.id)}
                        >
                          <MessageSquareText size={15} />
                          Study chat
                        </button>
                        <IconButton
                          label={`Remove ${doc.title} from course`}
                          onClick={() =>
                            update((p) => ({
                              ...p,
                              spaces: p.spaces.map((s) =>
                                s.id === space.id
                                  ? {
                                      ...s,
                                      documentIds: s.documentIds.filter(
                                        (id) => id !== doc.id,
                                      ),
                                    }
                                  : s,
                              ),
                            }))
                          }
                        >
                          <XSmall />
                        </IconButton>
                      </div>
                    </article>
                  ))}
                </div>
              ) : (
                <Empty title="Add your course material">
                  Choose a source from your vault or upload a lecture.
                </Empty>
              )}
              <button
                className="secondary ws-plan-button"
                disabled={!docs.length}
                onClick={() => setExam(true)}
              >
                <CalendarDays size={16} />
                Plan revision for an exam
              </button>
            </>
          )}
          {tab === "notes" && (
            <>
              <div className="ws-toolbar">
                <input
                  className="ws-search"
                  aria-label="Search notes"
                  placeholder="Search notes"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
                <button className="primary" onClick={() => setNoteEdit("new")}>
                  <Plus size={16} />
                  New note
                </button>
                <button
                  className="secondary"
                  onClick={() => void exportNotes("md")}
                >
                  <Download size={15} />
                  Markdown
                </button>
                <button
                  className="secondary"
                  onClick={() => void exportNotes("pdf")}
                >
                  <Download size={15} />
                  PDF
                </button>
              </div>
              {notes.length ? (
                notes.map((note) => (
                  <article className="ws-note" key={note.id}>
                    <header>
                      <h3>{note.title}</h3>
                      <div className="ws-actions">
                        <IconButton
                          label="Make revision card"
                          onClick={() => createCard(note)}
                        >
                          <Layers3 size={17} />
                        </IconButton>
                        <IconButton
                          label="Edit note"
                          onClick={() => setNoteEdit(note)}
                        >
                          <Pencil size={17} />
                        </IconButton>
                        <IconButton
                          label="Delete note"
                          onClick={() => {
                            update((p) => ({
                              ...p,
                              notes: p.notes.filter((n) => n.id !== note.id),
                            }));
                            undo("Note deleted", () =>
                              update((p) => ({
                                ...p,
                                notes: [note, ...p.notes],
                              })),
                            );
                          }}
                        >
                          <Trash2 size={17} />
                        </IconButton>
                      </div>
                    </header>
                    <p className="ws-note-text">{note.text}</p>
                    {note.documentId ? (
                      <button
                        className="ws-source-link"
                        onClick={() =>
                          openDocument(note.documentId, note.sourcePage)
                        }
                      >
                        <BookOpen size={14} />
                        {note.documentTitle}
                        {note.sourcePage
                          ? ` · Page ${note.sourcePage}`
                          : " · Page unavailable"}
                      </button>
                    ) : (
                      <small>Personal note</small>
                    )}
                  </article>
                ))
              ) : (
                <Empty
                  title={
                    search ? "No matching notes" : "Your notes will live here"
                  }
                >
                  Save an explanation from chat, capture a passage, or write a
                  note.
                </Empty>
              )}
            </>
          )}
          {tab === "revision" && (
            <>
              {review ? (
                activeCard ? (
                  <div className="ws-review">
                    <div className="ws-row">
                      <span className="ws-category">
                        {review.length} left in this session
                      </span>
                      <button className="link" onClick={() => setReview(null)}>
                        End session
                      </button>
                    </div>
                    <h2>{activeCard.front}</h2>
                    {revealed ? (
                      <>
                        <p className="ws-note-text">{activeCard.back}</p>
                        {activeCard.sourceExcerpt && (
                          <blockquote>{activeCard.sourceExcerpt}</blockquote>
                        )}
                        <button
                          className="ws-source-link"
                          onClick={() =>
                            openDocument(
                              activeCard.documentId,
                              activeCard.sourcePage,
                            )
                          }
                        >
                          {activeCard.documentTitle}
                          {activeCard.sourcePage
                            ? ` · Page ${activeCard.sourcePage}`
                            : " · Page unavailable"}
                        </button>
                        <div className="ws-review-ratings">
                          <button
                            className="secondary"
                            onClick={() => rate(false)}
                          >
                            <RotateCcw size={16} />
                            Again <small>in 10 minutes</small>
                          </button>
                          <button
                            className="primary"
                            onClick={() => rate(true)}
                          >
                            <Check size={16} />
                            Got it{" "}
                            <small>
                              {activeCard.intervalDays
                                ? `in ${Math.min(30, activeCard.intervalDays * 2)} days`
                                : "tomorrow"}
                            </small>
                          </button>
                        </div>
                      </>
                    ) : (
                      <button
                        className="primary"
                        onClick={() => setRevealed(true)}
                      >
                        Reveal answer
                      </button>
                    )}
                  </div>
                ) : (
                  <Empty
                    title="Session complete"
                    action={
                      <button
                        className="primary"
                        onClick={() => setReview(null)}
                      >
                        Back to revision
                      </button>
                    }
                  >
                    {reviewed} cards reviewed. Your next dates are saved.
                  </Empty>
                )
              ) : (
                <>
                  <div className="ws-toolbar">
                    <p>
                      {due.length} due now · {cards.length} cards total
                    </p>
                    <button
                      className="primary"
                      disabled={!due.length}
                      onClick={() => {
                        setReview(due.map((c) => c.id));
                        setRevealed(false);
                        setReviewed(0);
                      }}
                    >
                      <Layers3 size={16} />
                      Review due cards
                    </button>
                  </div>
                  {cards.length ? (
                    cards.map((card) => (
                      <article className="ws-card-row" key={card.id}>
                        <div>
                          <h3>{card.front}</h3>
                          <p>
                            {!card.dueAt ||
                            new Date(card.dueAt).getTime() <= Date.now()
                              ? "Due now"
                              : `Next review ${new Date(card.dueAt).toLocaleString("en-ZA", { dateStyle: "medium", timeStyle: "short" })}`}{" "}
                            · {card.reviews} reviews
                          </p>
                        </div>
                        <div className="ws-actions">
                          <IconButton
                            label="Edit revision card"
                            onClick={() => {
                              setCardEdit(card);
                              setFront(card.front);
                              setBack(card.back);
                            }}
                          >
                            <Pencil size={16} />
                          </IconButton>
                          <IconButton
                            label="Delete revision card"
                            onClick={() => {
                              update((p) => ({
                                ...p,
                                cards: p.cards.filter((c) => c.id !== card.id),
                              }));
                              undo("Card deleted", () =>
                                update((p) => ({
                                  ...p,
                                  cards: [...p.cards, card],
                                })),
                              );
                            }}
                          >
                            <Trash2 size={16} />
                          </IconButton>
                        </div>
                      </article>
                    ))
                  ) : (
                    <Empty title="Your revision deck is empty">
                      Make a card from a note or save a question after a quiz.
                    </Empty>
                  )}
                </>
              )}
            </>
          )}
        </>
      )}
      {editSpace && (
        <Modal
          title={editSpace === "new" ? "New course" : "Rename course"}
          onClose={() => setEditSpace(null)}
        >
          <form
            className="ws-form"
            onSubmit={(e) => {
              e.preventDefault();
              const name = spaceName.trim();
              if (!name) return;
              update((p) => ({
                ...p,
                spaces:
                  editSpace === "new"
                    ? [
                        ...p.spaces,
                        {
                          id: newId(),
                          name,
                          documentIds: [],
                          createdAt: new Date().toISOString(),
                        },
                      ]
                    : p.spaces.map((s) =>
                        s.id === editSpace.id ? { ...s, name } : s,
                      ),
              }));
              setEditSpace(null);
            }}
          >
            <label>
              Course name
              <input
                required
                maxLength={120}
                value={spaceName}
                onChange={(e) => setSpaceName(e.target.value)}
                placeholder="e.g. Database Systems"
              />
            </label>
            <div className="ws-form-actions">
              <button
                type="button"
                className="secondary"
                onClick={() => setEditSpace(null)}
              >
                Cancel
              </button>
              <button className="primary">
                {editSpace === "new" ? "Create course" : "Save name"}
              </button>
            </div>
          </form>
        </Modal>
      )}
      {attach && space && (
        <Modal title="Attach vault sources" onClose={() => setAttach(false)}>
          <div className="ws-checklist">
            {documents.length ? (
              documents.map((doc) => (
                <label key={doc.id}>
                  <input
                    type="checkbox"
                    checked={attachIds.includes(doc.id)}
                    onChange={(e) =>
                      setAttachIds((ids) =>
                        e.target.checked
                          ? [...ids, doc.id]
                          : ids.filter((id) => id !== doc.id),
                      )
                    }
                  />
                  <span>
                    <b>{doc.title}</b>
                    <small>
                      {doc.type} · {doc.status}
                    </small>
                  </span>
                </label>
              ))
            ) : (
              <p>No documents yet. Upload your first source.</p>
            )}
          </div>
          <div className="ws-form-actions">
            <button className="secondary" onClick={() => setAttach(false)}>
              Cancel
            </button>
            <button
              className="primary"
              onClick={() => {
                update((p) => ({
                  ...p,
                  spaces: p.spaces.map((s) =>
                    s.id === space.id ? { ...s, documentIds: attachIds } : s,
                  ),
                }));
                setAttach(false);
              }}
            >
              Save sources
            </button>
          </div>
        </Modal>
      )}
      {noteEdit && (
        <NoteEditor
          data={data}
          documents={documents}
          update={update}
          note={noteEdit === "new" ? undefined : noteEdit}
          seed={
            noteEdit === "new"
              ? {
                  text: "",
                  documentId: docs[0]?.id || "",
                  documentTitle: docs[0]?.title || "Personal note",
                  sourcePage: null,
                  spaceId: space?.id,
                }
              : undefined
          }
          onClose={() => setNoteEdit(null)}
          toast={toast}
        />
      )}
      {exam && space && (
        <Modal title="Your revision plan" onClose={() => setExam(false)}>
          <div className="ws-form">
            <label>
              Exam date
              <input
                type="date"
                required
                min={shiftDate(today(), 1)}
                value={examDate}
                onChange={(e) => setExamDate(e.target.value)}
              />
            </label>
            <div className="ws-plan">
              {plan.map((item) => (
                <div key={item.title}>
                  <b>
                    {new Date(`${item.due}T12:00:00`).toLocaleDateString(
                      "en-ZA",
                      { day: "numeric", month: "short", year: "numeric" },
                    )}
                  </b>
                  <span>{item.title}</span>
                </div>
              ))}
            </div>
            <div className="ws-form-actions">
              <button className="secondary" onClick={() => setExam(false)}>
                Cancel
              </button>
              <button
                className="primary"
                disabled={!plan.length}
                onClick={() => {
                  update((p) => ({
                    ...p,
                    tasks: [
                      ...p.tasks,
                      ...plan
                        .filter(
                          (item) =>
                            !p.tasks.some(
                              (t) =>
                                t.title === item.title && t.due === item.due,
                            ),
                        )
                        .map(
                          (item) =>
                            ({
                              ...item,
                              id: newId(),
                              priority: "Normal",
                              completed: false,
                              documentId: docs[0]?.id,
                            }) as Task,
                        ),
                    ],
                  }));
                  setExam(false);
                  toast("Revision plan added to Deadlines.");
                  openTasks();
                }}
              >
                Add to Deadlines
              </button>
            </div>
          </div>
        </Modal>
      )}
      {confirmDelete && space && (
        <Modal
          title={`Delete ${space.name}?`}
          onClose={() => setConfirmDelete(false)}
        >
          <p>
            Its notes and revision cards will be removed. Source files stay in
            your vault.
          </p>
          <div className="ws-form-actions">
            <button
              className="secondary"
              onClick={() => setConfirmDelete(false)}
            >
              Cancel
            </button>
            <button
              className="danger-button"
              onClick={() => {
                const removedNotes = data.notes.filter(
                    (n) => n.spaceId === space.id,
                  ),
                  removedCards = cards;
                update((p) => ({
                  ...p,
                  spaces: p.spaces.filter((s) => s.id !== space.id),
                  notes: p.notes.filter((n) => n.spaceId !== space.id),
                  cards: p.cards.filter((c) => c.spaceId !== space.id),
                }));
                undo("Course deleted", () =>
                  update((p) => ({
                    ...p,
                    spaces: [...p.spaces, space],
                    notes: [...p.notes, ...removedNotes],
                    cards: [...p.cards, ...removedCards],
                  })),
                );
                setConfirmDelete(false);
                selectSpace(null);
              }}
            >
              Delete course
            </button>
          </div>
        </Modal>
      )}
      {cardEdit && (
        <Modal title="Edit revision card" onClose={() => setCardEdit(null)}>
          <form
            className="ws-form"
            onSubmit={(e) => {
              e.preventDefault();
              update((p) => ({
                ...p,
                cards: p.cards.map((c) =>
                  c.id === cardEdit.id
                    ? { ...c, front: front.trim(), back: back.trim() }
                    : c,
                ),
              }));
              setCardEdit(null);
            }}
          >
            <label>
              Question
              <input
                required
                value={front}
                onChange={(e) => setFront(e.target.value)}
              />
            </label>
            <label>
              Answer
              <textarea
                required
                rows={6}
                value={back}
                onChange={(e) => setBack(e.target.value)}
              />
            </label>
            <div className="ws-form-actions">
              <button className="primary">Save card</button>
            </div>
          </form>
        </Modal>
      )}
    </section>
  );
}
function FileSample() {
  return <BookOpen size={16} />;
}
function XSmall() {
  return <Trash2 size={15} />;
}
