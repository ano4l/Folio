"use client";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  FolderOpen,
  LayoutDashboard,
  FileText,
  MessageSquareText,
  BookOpen,
  CalendarDays,
  ShieldCheck,
  LogOut,
  Upload,
  Wrench,
  Search,
  RefreshCw,
  Star,
  Trash2,
  Pencil,
  Download,
  Plus,
  ArrowRight,
  ArrowLeft,
  Clock3,
  Layers3,
  Fingerprint,
  Check,
  X,
  RotateCcw,
  UserRound,
  AlertCircle,
  ExternalLink,
  ListFilter,
} from "lucide-react";
import { api, listDocuments, recoverProcessing, uploadDocument } from "./api";
import {
  categories,
  newId,
  emptyWorkspace,
  dueCards,
  quizProgress,
  today,
  type User,
  type VaultDocument,
  type Task,
  type Activity,
} from "./models";
import { useWorkspaceData } from "./storage";
import { download, activityCsv, textPdf } from "./exports";
import StudyView, { NoteEditor, type NoteSeed } from "./StudyView";
import ChatView from "./ChatView";
import TasksView, { TaskEditor } from "./TasksView";
import DocumentReader from "./DocumentReader";
import DocumentTools from "./DocumentTools";
import { Empty, ErrorNotice, IconButton, Modal, PageHeader } from "./ui";
import { sampleText, sampleTitle } from "./sample";
import { extractDeadlines } from "./deadlines";
type Screen =
  "dashboard" | "documents" | "study" | "ask" | "deadlines" | "security";
type Job = {
  id: string;
  title: string;
  stage: string;
  documentId?: string;
  state: "running" | "done" | "error" | "cancelled";
  spaceId?: string;
};
const navigation = [
  ["dashboard", "Home", LayoutDashboard],
  ["documents", "Documents", FileText],
  ["study", "Study", BookOpen],
  ["ask", "Ask AI", MessageSquareText],
  ["deadlines", "Deadlines", CalendarDays],
  ["security", "Security", ShieldCheck],
] as const;
export default function Workspace({
  user,
  logout,
  registerPasskey,
}: {
  user: User;
  logout: () => Promise<void>;
  registerPasskey: () => void;
}) {
  const {
    data,
    update,
    ready,
    error: storageError,
    flush,
  } = useWorkspaceData(user.id);
  const [screen, setScreen] = useState<Screen>("dashboard"),
    [documents, setDocuments] = useState<VaultDocument[]>([]),
    [loading, setLoading] = useState(true),
    [documentError, setDocumentError] = useState("");
  const [documentId, setDocumentId] = useState<string | null>(null),
    [sourcePage, setSourcePage] = useState<number | null>(null),
    [spaceId, setSpaceId] = useState<string | null>(null),
    [chatDocument, setChatDocument] = useState<string | null>(null),
    [chatSpace, setChatSpace] = useState<string | null>(null),
    [initialQuestion, setInitialQuestion] = useState("");
  const [query, setQuery] = useState(""),
    [category, setCategory] = useState("All"),
    [favoritesOnly, setFavoritesOnly] = useState(false),
    [attentionOnly, setAttentionOnly] = useState(false),
    [sort, setSort] = useState("recent"),
    [recycle, setRecycle] = useState(false);
  const [metadata, setMetadata] = useState<VaultDocument | null>(null),
    [editTitle, setEditTitle] = useState(""),
    [editCategory, setEditCategory] = useState("Document"),
    [mutationBusy, setMutationBusy] = useState(false),
    [mutationError, setMutationError] = useState("");
  const [uploadOpen, setUploadOpen] = useState(false),
    [uploadFile, setUploadFile] = useState<File | null>(null),
    [uploadTitle, setUploadTitle] = useState(""),
    [uploadCategory, setUploadCategory] = useState("Document"),
    [uploadSpace, setUploadSpace] = useState<string | undefined>(),
    [toolsOpen, setToolsOpen] = useState(false),
    [activityOpen, setActivityOpen] = useState(false),
    [profileOpen, setProfileOpen] = useState(false);
  const [jobs, setJobs] = useState<Job[]>([]),
    [noteSeed, setNoteSeed] = useState<NoteSeed | null>(null),
    [taskDoc, setTaskDoc] = useState<string | null>(null),
    [deleteDoc, setDeleteDoc] = useState<VaultDocument | null>(null),
    [localClear, setLocalClear] = useState(false),
    [activityQuery, setActivityQuery] = useState(""),
    [activityCategory, setActivityCategory] = useState("All");
  const [notice, setNotice] = useState<{
    text: string;
    undo?: () => void;
  } | null>(null);
  const controllers = useRef(new Map<string, AbortController>()),
    lifetime = useRef(new AbortController()),
    loadVersion = useRef(0),
    currentData = useRef(data);
  currentData.current = data;
  const toast = useCallback((text: string) => setNotice({ text }), []),
    undo = useCallback(
      (text: string, restore: () => void) => setNotice({ text, undo: restore }),
      [],
    );
  useEffect(() => {
    if (notice) {
      const timer = setTimeout(
        () => setNotice(null),
        notice.undo ? 10000 : 5000,
      );
      return () => clearTimeout(timer);
    }
  }, [notice]);
  const refresh = useCallback(async () => {
    const version = ++loadVersion.current;
    setLoading(true);
    setDocumentError("");
    try {
      const items = await listDocuments(lifetime.current.signal);
      if (!lifetime.current.signal.aborted && loadVersion.current === version)
        setDocuments(items);
    } catch (problem) {
      if (!lifetime.current.signal.aborted && loadVersion.current === version)
        setDocumentError(
          problem instanceof Error
            ? problem.message
            : "Unable to load documents.",
        );
    } finally {
      if (!lifetime.current.signal.aborted && loadVersion.current === version)
        setLoading(false);
    }
  }, []);
  useEffect(() => {
    lifetime.current = new AbortController();
    void refresh();
    return () => {
      lifetime.current.abort();
      controllers.current.forEach((controller) => controller.abort());
    };
  }, [refresh]);
  useEffect(() => {
    if (!ready || !documents.length) return;
    const candidates = extractDeadlines(documents).filter(
      (candidate) => candidate.due,
    );
    update((previous) => {
      const fresh = candidates.filter(
        (candidate) =>
          !previous.dismissedImports.includes(candidate.key) &&
          !previous.tasks.some((task) => task.importKey === candidate.key),
      );
      if (!fresh.length) return previous;
      const tasks: Task[] = fresh.map((candidate) => ({
        id: newId(),
        title: candidate.action,
        due: candidate.due!,
        priority: "Normal",
        completed: false,
        documentId: candidate.documentId,
        sourcePage: candidate.page,
        excerpt: candidate.excerpt,
        importKey: candidate.key,
      }));
      return { ...previous, tasks: [...previous.tasks, ...tasks] };
    });
  }, [ready, documents]);
  const activity = (
    action: string,
    category: Activity["category"],
    detail: string,
  ) =>
    update((previous) => ({
      ...previous,
      activity: [
        { id: newId(), at: new Date().toISOString(), action, category, detail },
        ...previous.activity,
      ].slice(0, 300),
    }));
  const openDocument = (id: string, page: number | null = null) => {
    if (!documents.some((doc) => doc.id === id)) {
      toast("This source is not available in your vault.");
      return;
    }
    setScreen("documents");
    setDocumentId(id);
    setSourcePage(page);
    activity(
      "Document opened",
      "Access",
      documents.find((doc) => doc.id === id)!.title,
    );
  };
  const openChat = (id: string, course?: string) => {
    setChatDocument(id);
    setChatSpace(course || null);
    setDocumentId(null);
    setScreen("ask");
  };
  const go = (target: Screen) => {
    setScreen(target);
    setDocumentId(null);
    setRecycle(false);
    setProfileOpen(false);
  };
  const beginUpload = (course?: string, file?: File, title?: string) => {
    setUploadFile(file || null);
    setUploadTitle(title || "");
    setUploadCategory(course ? "Lecture Notes" : "Document");
    setUploadSpace(course);
    setUploadOpen(true);
    setMutationError("");
  };
  const uploadSample = async (course: string) => {
    try {
      const bytes = await textPdf(sampleTitle, sampleText);
      await startUpload(
        new File([bytes], "relational-databases-sample.pdf", {
          type: "application/pdf",
        }),
        sampleTitle,
        "Lecture Notes",
        course,
      );
    } catch (problem) {
      toast(
        problem instanceof Error
          ? problem.message
          : "Unable to prepare sample lecture.",
      );
    }
  };
  const changeJob = (id: string, changes: Partial<Job>) => {
    if (!lifetime.current.signal.aborted)
      setJobs((previous) =>
        previous.map((job) => (job.id === id ? { ...job, ...changes } : job)),
      );
  };
  const startUpload = async (
    file: File,
    title: string,
    category: string,
    course?: string,
  ) => {
    const id = newId(),
      controller = new AbortController();
    controllers.current.set(id, controller);
    setJobs((previous) =>
      [
        {
          id,
          title,
          stage: "Preparing secure upload",
          state: "running" as const,
          spaceId: course,
        },
        ...previous,
      ].slice(0, 10),
    );
    setUploadOpen(false);
    toast("Upload started. You can keep working.");
    let storedId: string | undefined;
    try {
      await uploadDocument(
        file,
        title,
        category,
        controller.signal,
        (stage) => changeJob(id, { stage }),
        (documentId) => {
          storedId = documentId;
          changeJob(id, { documentId });
          if (course)
            update((previous) => ({
              ...previous,
              spaces: previous.spaces.map((space) =>
                space.id === course
                  ? {
                      ...space,
                      documentIds: [
                        ...new Set([...space.documentIds, documentId]),
                      ],
                    }
                  : space,
              ),
            }));
          void refresh();
        },
      );
      if (controller.signal.aborted) return;
      changeJob(id, { stage: "Saved in your vault", state: "done" });
      activity("Document uploaded", "Document", title);
      await refresh();
      toast("Document saved in your vault.");
    } catch (problem) {
      if (controller.signal.aborted) {
        changeJob(id, {
          stage: storedId
            ? "Stopped waiting. Original saved"
            : "Upload cancelled",
          state: "cancelled",
        });
        return;
      }
      changeJob(id, {
        stage: problem instanceof Error ? problem.message : "Upload failed",
        state: "error",
        documentId: storedId,
      });
      await refresh();
      toast(
        storedId
          ? "Original saved. Retry processing from the vault."
          : "Upload failed. Open activity for details.",
      );
    } finally {
      controllers.current.delete(id);
    }
  };
  const retryProcessing = async (doc: VaultDocument) => {
    if (
      jobs.some((job) => job.state === "running" && job.documentId === doc.id)
    ) {
      setActivityOpen(true);
      return;
    }
    const id = newId(),
      controller = new AbortController();
    controllers.current.set(id, controller);
    setJobs((previous) =>
      [
        {
          id,
          title: doc.title,
          documentId: doc.id,
          stage: "Retrying processing",
          state: "running" as const,
        },
        ...previous,
      ].slice(0, 10),
    );
    try {
      const status = await recoverProcessing(
        doc.id,
        controller.signal,
        (stage) => changeJob(id, { stage }),
      );
      changeJob(id, {
        stage: status,
        state: status === "Ready" ? "done" : "error",
      });
      await refresh();
    } catch (problem) {
      changeJob(id, {
        stage: controller.signal.aborted
          ? "Stopped waiting"
          : problem instanceof Error
            ? problem.message
            : "Processing failed",
        state: controller.signal.aborted ? "cancelled" : "error",
      });
    } finally {
      controllers.current.delete(id);
    }
  };
  const original = async (doc: VaultDocument) => {
    try {
      const result = await api<{ url: string }>(
        "documents/source",
        { documentId: doc.id },
        lifetime.current.signal,
      );
      const link = document.createElement("a");
      link.href = result.url;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.click();
      activity("Original file opened", "Document", doc.title);
    } catch (problem) {
      toast(
        problem instanceof Error ? problem.message : "Original unavailable.",
      );
    }
  };
  const restore = async (id: string, title: string) => {
    try {
      await api(
        "documents/restore",
        { documentId: id },
        lifetime.current.signal,
      );
      update((previous) => ({
        ...previous,
        recycled: previous.recycled.filter((doc) => doc.id !== id),
      }));
      await refresh();
      toast("Document restored.");
      activity("Document restored", "Document", title);
    } catch (problem) {
      toast(problem instanceof Error ? problem.message : "Restore failed.");
    }
  };
  const selectedDoc = documents.find((doc) => doc.id === documentId);
  const visibleDocuments = useMemo(
    () =>
      documents
        .filter(
          (doc) =>
            `${doc.title} ${doc.type} ${doc.summary} ${doc.rawText || ""}`
              .toLowerCase()
              .includes(query.toLowerCase()) &&
            (category === "All" || doc.type === category) &&
            (!favoritesOnly || data.favorites.includes(doc.id)) &&
            (!attentionOnly || doc.status !== "Ready"),
        )
        .sort((a, b) =>
          sort === "title"
            ? a.title.localeCompare(b.title)
            : sort === "pages"
              ? b.pages - a.pages
              : new Date(b.date).getTime() - new Date(a.date).getTime(),
        ),
    [
      documents,
      query,
      category,
      favoritesOnly,
      attentionOnly,
      sort,
      data.favorites,
    ],
  );
  const upcoming = data.tasks
      .filter((task) => !task.completed)
      .sort((a, b) => a.due.localeCompare(b.due)),
    due = dueCards(data.cards),
    progress = quizProgress(Object.values(data.quizzes));
  const localActivity = data.activity.filter(
    (item) =>
      (activityCategory === "All" || item.category === activityCategory) &&
      `${item.action} ${item.detail}`
        .toLowerCase()
        .includes(activityQuery.toLowerCase()),
  );
  const running = jobs.filter((job) => job.state === "running");
  const renderDocument = (doc: VaultDocument) => (
    <article className="ws-vault-row" key={doc.id}>
      <button className="ws-document-open" onClick={() => openDocument(doc.id)}>
        <span className="ws-doc-icon">
          <FileText size={24} />
        </span>
        <span>
          <span className="ws-category">{doc.type}</span>
          <b>{doc.title}</b>
          <small>
            {doc.pages > 0 ? `${doc.pages} pages` : "Pages unavailable"} ·{" "}
            {doc.status}
          </small>
          <p className="ws-clamp">{doc.summary || "Summary pending"}</p>
        </span>
      </button>
      <div className="ws-doc-controls">
        <IconButton
          label={
            data.favorites.includes(doc.id)
              ? "Remove favorite"
              : "Favorite document"
          }
          onClick={() =>
            update((previous) => ({
              ...previous,
              favorites: previous.favorites.includes(doc.id)
                ? previous.favorites.filter((id) => id !== doc.id)
                : [...previous.favorites, doc.id],
            }))
          }
        >
          <Star
            size={16}
            fill={data.favorites.includes(doc.id) ? "currentColor" : "none"}
          />
        </IconButton>
        <IconButton
          label="Edit document title and category"
          onClick={() => {
            setMetadata(doc);
            setEditTitle(doc.title);
            setEditCategory(doc.type);
            setMutationError("");
          }}
        >
          <Pencil size={16} />
        </IconButton>
        <IconButton
          label="Open original file"
          onClick={() => void original(doc)}
        >
          <Download size={16} />
        </IconButton>
        <IconButton
          label="Create document task"
          onClick={() => setTaskDoc(doc.id)}
        >
          <CalendarDays size={16} />
        </IconButton>
        <IconButton
          label="Chat with this document"
          onClick={() => openChat(doc.id)}
        >
          <MessageSquareText size={16} />
        </IconButton>
        <IconButton
          label="Add document to Study"
          onClick={() => {
            setScreen("study");
            setSpaceId(null);
            setAttachCourse("");
            setNewCourse("");
            setStudyAttach(doc.id);
          }}
        >
          <BookOpen size={16} />
        </IconButton>
        {doc.status !== "Ready" && (
          <IconButton
            label="Retry document processing"
            onClick={() => void retryProcessing(doc)}
          >
            <RotateCcw size={16} />
          </IconButton>
        )}
        <IconButton
          label="Move document to recycle bin"
          onClick={() => {
            setDeleteDoc(doc);
            setMutationError("");
          }}
        >
          <Trash2 size={16} />
        </IconButton>
      </div>
    </article>
  );
  const [studyAttach, setStudyAttach] = useState<string | null>(null),
    [attachCourse, setAttachCourse] = useState(""),
    [newCourse, setNewCourse] = useState("");
  const consumeQuestion = useCallback(() => setInitialQuestion(""), []);
  if (!ready)
    return (
      <div className="ws-loading">
        <FolderOpen size={26} />
        <h2>Opening your workspace</h2>
        <ErrorNotice message={storageError} />
        {storageError && (
          <button
            className="secondary"
            onClick={() => window.location.reload()}
          >
            Retry
          </button>
        )}
      </div>
    );
  return (
    <main className="ws-shell">
      <aside className="ws-sidebar">
        <div className="ws-brand">
          <span>
            <FolderOpen size={22} />
          </span>
          <b>
            Folio<small>Documents & study</small>
          </b>
        </div>
        <nav aria-label="Main navigation">
          {navigation.map(([key, label, Icon]) => (
            <button
              className={screen === key ? "active" : ""}
              aria-current={screen === key ? "page" : undefined}
              key={key}
              onClick={() => go(key)}
            >
              <Icon size={18} />
              <span>{label}</span>
              {key === "deadlines" && upcoming.length > 0 && (
                <small>{upcoming.length}</small>
              )}
            </button>
          ))}
          {user.isAdmin && <a className="ws-admin-link" href="/admin"><ShieldCheck size={18} /><span>Administration</span><ExternalLink size={13} /></a>}
        </nav>
        <div className="ws-sidebar-bottom">
          <div className="ws-account">
            <span>
              {user.displayName
                .split(" ")
                .map((word) => word[0])
                .join("")
                .slice(0, 2)}
            </span>
            <div>
              <b>{user.displayName}</b>
              <small>{user.email}</small>
            </div>
          </div>
          <button
            className="ws-signout"
            onClick={() => void flush().then(logout)}
          >
            <LogOut size={17} />
            Sign out
          </button>
        </div>
      </aside>
      <div className="ws-main">
        <header className="ws-topbar">
          <div className="ws-mobile-brand">
            <FolderOpen size={23} />
            <b>Folio</b>
          </div>
          <div className="ws-topbar-search">
            <Search size={17} />
            <input
              aria-label="Search your vault"
              placeholder="Search your vault"
              value={query}
              onChange={(event) => {
                setQuery(event.target.value);
                setScreen("documents");
                setDocumentId(null);
              }}
            />
          </div>
          <div className="ws-actions">
            <button
              className="ws-activity-toggle"
              onClick={() => setActivityOpen(true)}
              aria-label={`Upload activity${running.length ? `, ${running.length} running` : ""}`}
              title="Upload activity"
            >
              <Upload size={18} />
              {running.length > 0 && <span>{running.length}</span>}
            </button>
            <IconButton
              label="Document tools"
              onClick={() => setToolsOpen(true)}
            >
              <Wrench size={19} />
            </IconButton>
            <button
              className="primary ws-upload-trigger"
              aria-label="Upload document"
              title="Upload document"
              onClick={() => beginUpload()}
            >
              <Plus size={16} />
              <span>Upload</span>
            </button>
            <IconButton
              className="ws-mobile-profile"
              label="Account and security"
              onClick={() => setProfileOpen(true)}
            >
              <UserRound size={19} />
            </IconButton>
          </div>
        </header>
        <div className="ws-content">
          <ErrorNotice message={storageError} />
          {screen === "dashboard" && (
            <section className="ws-view">
              <PageHeader
                title={`Hello, ${user.displayName.split(" ")[0]}`}
                subtitle={new Date().toLocaleDateString("en-ZA", {
                  weekday: "long",
                  day: "numeric",
                  month: "long",
                  year: "numeric",
                })}
              />
              <div className="ws-overview">
                <button onClick={() => go("documents")}>
                  <FileText size={20} />
                  <strong>{documents.length}</strong>
                  <span>Documents</span>
                </button>
                <button onClick={() => go("study")}>
                  <BookOpen size={20} />
                  <strong>{data.spaces.length}</strong>
                  <span>Courses</span>
                </button>
                <button onClick={() => go("deadlines")}>
                  <CalendarDays size={20} />
                  <strong>{upcoming.length}</strong>
                  <span>Open tasks</span>
                </button>
                <button onClick={() => go("study")}>
                  <Layers3 size={20} />
                  <strong>{due.length}</strong>
                  <span>Cards due</span>
                </button>
              </div>
              <div className="ws-dashboard-columns">
                <section>
                  <div className="ws-section-heading">
                    <h2>Recent documents</h2>
                    <button className="link" onClick={() => go("documents")}>
                      View vault <ArrowRight size={15} />
                    </button>
                  </div>
                  <ErrorNotice message={documentError} />
                  {loading ? (
                    <p className="ws-loading-inline">Loading documents...</p>
                  ) : documents.length ? (
                    documents.slice(0, 4).map((doc) => (
                      <button
                        className="ws-recent"
                        key={doc.id}
                        onClick={() => openDocument(doc.id)}
                      >
                        <FileText size={20} />
                        <span>
                          <b>{doc.title}</b>
                          <small>
                            {doc.type} · {doc.status}
                          </small>
                        </span>
                        <ArrowRight size={17} />
                      </button>
                    ))
                  ) : (
                    <Empty
                      title="Your vault is ready"
                      action={
                        <button
                          className="primary"
                          onClick={() => beginUpload()}
                        >
                          <Upload size={16} />
                          Upload your first document
                        </button>
                      }
                    >
                      Add a lecture, letter or document to get started.
                    </Empty>
                  )}
                </section>
                <section>
                  <div className="ws-section-heading">
                    <h2>Coming up</h2>
                    <button className="link" onClick={() => go("deadlines")}>
                      All tasks <ArrowRight size={15} />
                    </button>
                  </div>
                  {upcoming.length ? (
                    upcoming.slice(0, 4).map((task) => (
                      <button
                        className="ws-upcoming"
                        key={task.id}
                        onClick={() => go("deadlines")}
                      >
                        <CalendarDays size={18} />
                        <span>
                          <b>{task.title}</b>
                          <small
                            className={task.due < today() ? "ws-overdue" : ""}
                          >
                            {new Date(
                              `${task.due}T12:00:00`,
                            ).toLocaleDateString("en-ZA", {
                              day: "numeric",
                              month: "short",
                              year: "numeric",
                            })}{" "}
                            · {task.priority}
                          </small>
                        </span>
                      </button>
                    ))
                  ) : (
                    <Empty title="No upcoming tasks">
                      Your personal tasks and confirmed source dates will appear
                      here.
                    </Empty>
                  )}
                </section>
              </div>
              <section className="ws-study-summary">
                <BookOpen size={24} />
                <div>
                  <h2>Pick up your studies</h2>
                  <p>
                    {progress.answered
                      ? `${progress.correct} of ${progress.answered} recorded quiz answers correct. `
                      : ""}
                    {due.length
                      ? `${due.length} revision cards are due.`
                      : "Explore a course source or build your next revision deck."}
                  </p>
                </div>
                <button className="primary" onClick={() => go("study")}>
                  Open Study <ArrowRight size={16} />
                </button>
              </section>
            </section>
          )}
          {screen === "documents" && selectedDoc ? (
            <DocumentReader
              key={`${selectedDoc.id}:${sourcePage}`}
              doc={selectedDoc}
              initialPage={sourcePage}
              onBack={() => setDocumentId(null)}
              ask={(question) => {
                setInitialQuestion(question);
                openChat(selectedDoc.id);
              }}
              saveNote={setNoteSeed}
              toast={toast}
            />
          ) : (
            screen === "documents" && (
              <section className="ws-view">
                <PageHeader
                  title={recycle ? "Recycle bin" : "Documents"}
                  subtitle={
                    recycle
                      ? "Documents you moved here from this browser."
                      : `${documents.length} documents in your vault`
                  }
                >
                  <IconButton
                    label="Refresh documents"
                    onClick={() => void refresh()}
                    disabled={loading}
                  >
                    <RefreshCw size={18} className={loading ? "spin" : ""} />
                  </IconButton>
                  <button
                    className="secondary"
                    onClick={() => setRecycle(!recycle)}
                  >
                    {recycle ? <ArrowLeft size={16} /> : <Trash2 size={16} />}
                    {recycle ? "Back to vault" : "Recycle bin"}
                  </button>
                </PageHeader>
                <ErrorNotice message={documentError} />
                {recycle ? (
                  data.recycled.length ? (
                    data.recycled.map((doc) => (
                      <article className="ws-recycled" key={doc.id}>
                        <FileText size={21} />
                        <div>
                          <b>{doc.title}</b>
                          <p>{doc.type}</p>
                        </div>
                        <button
                          className="secondary"
                          onClick={() => void restore(doc.id, doc.title)}
                        >
                          <RotateCcw size={15} />
                          Restore
                        </button>
                      </article>
                    ))
                  ) : (
                    <Empty title="Your recycle bin is empty" />
                  )
                ) : (
                  <>
                    <div className="ws-vault-filters">
                      <input
                        className="ws-search"
                        aria-label="Search documents"
                        placeholder="Search title, category or source text"
                        value={query}
                        onChange={(e) => setQuery(e.target.value)}
                      />
                      <label className="ws-filter-label">
                        Category
                        <select
                          aria-label="Filter document category"
                          value={category}
                          onChange={(e) => setCategory(e.target.value)}
                        >
                          <option>All</option>
                          {[
                            ...new Set([
                              ...categories,
                              ...documents.map((d) => d.type),
                            ]),
                          ].map((item) => (
                            <option key={item}>{item}</option>
                          ))}
                        </select>
                      </label>
                      <label className="ws-filter-label">
                        Sort
                        <select
                          aria-label="Sort documents"
                          value={sort}
                          onChange={(e) => setSort(e.target.value)}
                        >
                          <option value="recent">Recent first</option>
                          <option value="title">Title A-Z</option>
                          <option value="pages">Most pages</option>
                        </select>
                      </label>
                      <button
                        className={`secondary ${favoritesOnly ? "selected" : ""}`}
                        aria-pressed={favoritesOnly}
                        onClick={() => setFavoritesOnly(!favoritesOnly)}
                      >
                        <Star size={15} />
                        Favorites
                      </button>
                      <button
                        className={`secondary ${attentionOnly ? "selected" : ""}`}
                        aria-pressed={attentionOnly}
                        onClick={() => setAttentionOnly(!attentionOnly)}
                      >
                        <AlertCircle size={15} />
                        Needs attention
                      </button>
                    </div>
                    {loading ? (
                      <p className="ws-loading-inline">
                        Loading your documents...
                      </p>
                    ) : visibleDocuments.length ? (
                      <div className="ws-vault-list">
                        {visibleDocuments.map(renderDocument)}
                      </div>
                    ) : (
                      <Empty
                        title={
                          documents.length
                            ? "No documents match these filters"
                            : "Your vault is ready for its first document"
                        }
                        action={
                          !documents.length ? (
                            <button
                              className="primary"
                              onClick={() => beginUpload()}
                            >
                              <Upload size={16} />
                              Upload a document
                            </button>
                          ) : (
                            <button
                              className="secondary"
                              onClick={() => {
                                setQuery("");
                                setCategory("All");
                                setFavoritesOnly(false);
                                setAttentionOnly(false);
                              }}
                            >
                              Clear filters
                            </button>
                          )
                        }
                      />
                    )}
                  </>
                )}
              </section>
            )
          )}
          {screen === "study" && (
            <StudyView
              data={data}
              update={update}
              documents={documents}
              selectedSpace={spaceId}
              selectSpace={setSpaceId}
              openDocument={openDocument}
              openChat={openChat}
              upload={beginUpload}
              sample={(course) => void uploadSample(course)}
              toast={toast}
              undo={undo}
              openTasks={() => go("deadlines")}
            />
          )}
          {screen === "ask" && (
            <ChatView
              data={data}
              update={update}
              documents={documents}
              documentId={chatDocument}
              spaceId={chatSpace}
              setContext={(doc, space) => {
                setChatDocument(doc);
                setChatSpace(space || null);
              }}
              openDocument={openDocument}
              saveNote={setNoteSeed}
              toast={toast}
              initialQuestion={initialQuestion}
              consumeQuestion={consumeQuestion}
              activity={activity}
            />
          )}
          {screen === "deadlines" && (
            <TasksView
              data={data}
              update={update}
              documents={documents}
              openDocument={openDocument}
              undo={undo}
              activity={(action, detail) => activity(action, "Tasks", detail)}
            />
          )}
          {screen === "security" && (
            <section className="ws-view">
              <PageHeader
                title="Security & activity"
                subtitle="Your account and this browser’s workspace."
              />
              <section className="ws-security-section">
                <div>
                  <ShieldCheck size={22} />
                  <div>
                    <h3>Email verification</h3>
                    <p>A one-time code is required after password sign-in.</p>
                  </div>
                  <span className="ws-required">
                    <Check size={14} />
                    Required
                  </span>
                </div>
                <div>
                  <Fingerprint size={22} />
                  <div>
                    <h3>Passkey sign-in</h3>
                    <p>Use your device’s supported passkey authenticator.</p>
                  </div>
                  <button className="secondary" onClick={registerPasskey}>
                    Add passkey
                  </button>
                </div>
                <div>
                  <UserRound size={22} />
                  <div>
                    <h3>Current account</h3>
                    <p>
                      {user.displayName}
                      <br />
                      {user.email}
                    </p>
                  </div>
                  <button
                    className="secondary"
                    onClick={() => void flush().then(logout)}
                  >
                    <LogOut size={15} />
                    Sign out
                  </button>
                </div>
              </section>
              <section className="ws-browser-data">
                <h2>Saved in this browser</h2>
                <p>
                  Course spaces, notes, cards, chats, favorites, tasks and
                  activity are stored for this account in encrypted browser
                  storage. They do not sync with the mobile app or another
                  browser. Your original documents remain in your cloud vault.
                </p>
                <p>
                  Browser storage uses a key kept on this device. Anyone with
                  access to your browser profile or a compromised page may still
                  access it. Sign out on a shared device.
                </p>
                <button
                  className="secondary"
                  onClick={() => setLocalClear(true)}
                >
                  <Trash2 size={15} />
                  Clear browser workspace
                </button>
              </section>
              <section className="ws-activity-section">
                <div className="ws-section-heading">
                  <h2>Local activity</h2>
                  <button
                    className="secondary"
                    onClick={() =>
                      download(
                        new Blob([activityCsv(localActivity)], {
                          type: "text/csv;charset=utf-8",
                        }),
                        "Folio activity.csv",
                      )
                    }
                  >
                    <Download size={15} />
                    Export CSV
                  </button>
                </div>
                <p>
                  Up to 300 recent actions recorded in this browser. This is not
                  a server audit ledger.
                </p>
                <div className="ws-toolbar">
                  <input
                    className="ws-search"
                    aria-label="Search local activity"
                    value={activityQuery}
                    onChange={(e) => setActivityQuery(e.target.value)}
                    placeholder="Search activity"
                  />
                  <select
                    aria-label="Activity category"
                    value={activityCategory}
                    onChange={(e) => setActivityCategory(e.target.value)}
                  >
                    {[
                      "All",
                      "Access",
                      "Document",
                      "Study",
                      "Security",
                      "AI Queries",
                      "Tasks",
                    ].map((item) => (
                      <option key={item}>{item}</option>
                    ))}
                  </select>
                </div>
                {localActivity.length ? (
                  localActivity.map((item) => (
                    <article className="ws-activity-row" key={item.id}>
                      <span className="ws-category">{item.category}</span>
                      <div>
                        <h3>{item.action}</h3>
                        <p>{item.detail}</p>
                      </div>
                      <time>
                        {new Date(item.at).toLocaleString("en-ZA", {
                          dateStyle: "medium",
                          timeStyle: "short",
                        })}
                      </time>
                    </article>
                  ))
                ) : (
                  <Empty title="No matching activity" />
                )}
              </section>
            </section>
          )}
        </div>
      </div>
      <nav className="ws-phone-nav" aria-label="Phone navigation">
        {navigation
          .filter((item) => item[0] !== "security")
          .map(([key, label, Icon]) => (
            <button
              key={key}
              className={screen === key ? "active" : ""}
              aria-current={screen === key ? "page" : undefined}
              onClick={() => go(key)}
            >
              <Icon size={20} />
              <span>
                {label === "Documents"
                  ? "Docs"
                  : label === "Deadlines"
                    ? "Tasks"
                    : label}
              </span>
            </button>
          ))}
      </nav>
      {notice && (
        <div className="ws-toast" role="status">
          <span>{notice.text}</span>
          {notice.undo && (
            <button
              onClick={() => {
                notice.undo?.();
                setNotice(null);
              }}
            >
              Undo
            </button>
          )}
          <IconButton label="Dismiss message" onClick={() => setNotice(null)}>
            <X size={15} />
          </IconButton>
        </div>
      )}
      {uploadOpen && (
        <Modal title="Upload document" onClose={() => setUploadOpen(false)}>
          <form
            className="ws-form"
            onSubmit={(event) => {
              event.preventDefault();
              if (uploadFile && uploadTitle.trim())
                void startUpload(
                  uploadFile,
                  uploadTitle.trim(),
                  uploadCategory,
                  uploadSpace,
                );
            }}
          >
            <label>
              Title
              <input
                required
                value={uploadTitle}
                maxLength={160}
                onChange={(e) => setUploadTitle(e.target.value)}
                placeholder="Give the source a clear name"
              />
            </label>
            <label>
              Category
              <select
                value={uploadCategory}
                onChange={(e) => setUploadCategory(e.target.value)}
              >
                {categories.map((item) => (
                  <option key={item}>{item}</option>
                ))}
              </select>
            </label>
            <label className="ws-file-picker">
              <Upload size={26} />
              <span>{uploadFile?.name || "Choose PDF, DOCX or an image"}</span>
              <small>Up to 20 MB · PDF up to 100 pages</small>
              <input
                required={!uploadFile}
                type="file"
                accept="application/pdf,.docx,image/jpeg,image/png"
                onChange={(event) => {
                  const file = event.target.files?.[0];
                  if (!file) return;
                  if (file.size > 20 * 1024 * 1024) {
                    setMutationError("Choose a file up to 20 MB.");
                    return;
                  }
                  setMutationError("");
                  setUploadFile(file);
                  if (!uploadTitle)
                    setUploadTitle(file.name.replace(/\.[^.]+$/, ""));
                }}
              />
            </label>
            {uploadSpace && (
              <p>
                Will be attached to{" "}
                {data.spaces.find((s) => s.id === uploadSpace)?.name} after
                storage confirms the upload.
              </p>
            )}
            <ErrorNotice message={mutationError} />
            <div className="ws-form-actions">
              <button
                className="secondary"
                type="button"
                onClick={() => setUploadOpen(false)}
              >
                Cancel
              </button>
              <button
                className="primary"
                type="submit"
                disabled={!uploadFile || !uploadTitle.trim()}
              >
                <Upload size={16} />
                Upload & analyse
              </button>
            </div>
          </form>
        </Modal>
      )}
      {toolsOpen && (
        <DocumentTools
          onClose={() => setToolsOpen(false)}
          upload={(file, title) => beginUpload(undefined, file, title)}
        />
      )}
      {activityOpen && (
        <Modal title="Upload activity" onClose={() => setActivityOpen(false)}>
          <div className="ws-job-list">
            {jobs.length ? (
              jobs.map((job) => (
                <article key={job.id}>
                  <div>
                    <h3>{job.title}</h3>
                    <p>{job.stage}</p>
                    <small>
                      {job.state === "running" ? "In progress" : job.state}
                    </small>
                  </div>
                  {job.state === "running" ? (
                    <button
                      className="secondary"
                      onClick={() => controllers.current.get(job.id)?.abort()}
                    >
                      Stop waiting
                    </button>
                  ) : job.documentId ? (
                    <button
                      className="link"
                      onClick={() => {
                        openDocument(job.documentId!);
                        setActivityOpen(false);
                      }}
                    >
                      Open source
                    </button>
                  ) : null}
                </article>
              ))
            ) : (
              <Empty title="No uploads in this session" />
            )}
          </div>
        </Modal>
      )}
      {profileOpen && (
        <Modal title="Your account" onClose={() => setProfileOpen(false)}>
          <div className="ws-form">
            <h3>{user.displayName}</h3>
            <p>{user.email}</p>
            <button className="secondary" onClick={() => go("security")}>
              <ShieldCheck size={16} />
              Security & activity
            </button>
            {user.isAdmin && <a className="secondary" href="/admin"><ShieldCheck size={16} />Administration</a>}
            <button
              className="secondary"
              onClick={() => void flush().then(logout)}
            >
              <LogOut size={16} />
              Sign out
            </button>
          </div>
        </Modal>
      )}
      {metadata && (
        <Modal title="Edit document details" onClose={() => setMetadata(null)}>
          <form
            className="ws-form"
            onSubmit={(event) => {
              event.preventDefault();
              if (mutationBusy) return;
              if (!editCategory.trim()) {
                setMutationError("Enter a category.");
                return;
              }
              setMutationBusy(true);
              setMutationError("");
              void api(
                "documents/update",
                {
                  documentId: metadata.id,
                  title: editTitle.trim(),
                  category: editCategory.trim(),
                },
                lifetime.current.signal,
              )
                .then(async () => {
                  await refresh();
                  activity("Document details updated", "Document", editTitle);
                  setMetadata(null);
                  toast("Document details updated.");
                })
                .catch((problem) =>
                  setMutationError(
                    problem instanceof Error
                      ? problem.message
                      : "Update failed.",
                  ),
                )
                .finally(() => setMutationBusy(false));
            }}
          >
            <label>
              Title
              <input
                required
                maxLength={160}
                value={editTitle}
                onChange={(event) => setEditTitle(event.target.value)}
              />
            </label>
            <label>
              Category
              <input
                required
                maxLength={80}
                disabled={mutationBusy}
                list="ws-category-suggestions"
                value={editCategory}
                onChange={(event) => setEditCategory(event.target.value)}
              />
              <datalist id="ws-category-suggestions">
                {[
                  ...new Set([
                    ...categories,
                    ...documents.map((doc) => doc.type),
                  ]),
                ].map((item) => (
                  <option key={item} value={item} />
                ))}
              </datalist>
            </label>
            <ErrorNotice message={mutationError} />
            <div className="ws-form-actions">
              <button
                type="button"
                className="secondary"
                onClick={() => setMetadata(null)}
              >
                Cancel
              </button>
              <button className="primary" disabled={mutationBusy}>
                {mutationBusy ? "Saving..." : "Save details"}
              </button>
            </div>
          </form>
        </Modal>
      )}
      {noteSeed && (
        <NoteEditor
          data={data}
          documents={documents}
          update={update}
          seed={noteSeed}
          toast={toast}
          onClose={() => setNoteSeed(null)}
        />
      )}
      {taskDoc && (
        <TaskEditor
          documentId={taskDoc}
          documents={documents}
          onClose={() => setTaskDoc(null)}
          onSave={(task) => {
            update((previous) => ({
              ...previous,
              tasks: [...previous.tasks, task],
            }));
            toast("Task saved in Deadlines.");
            activity("Task created", "Tasks", task.title);
          }}
        />
      )}
      {deleteDoc && (
        <Modal title="Move to recycle bin?" onClose={() => setDeleteDoc(null)}>
          <p>{deleteDoc.title} can be restored from the recycle bin.</p>
          <ErrorNotice message={mutationError} />
          <div className="ws-form-actions">
            <button className="secondary" onClick={() => setDeleteDoc(null)}>
              Cancel
            </button>
            <button
              className="danger-button"
              disabled={mutationBusy}
              onClick={() => {
                if (mutationBusy) return;
                const doc = deleteDoc;
                setMutationBusy(true);
                void api(
                  `documents/${doc.id}`,
                  undefined,
                  lifetime.current.signal,
                  "DELETE",
                )
                  .then(() => {
                    setDocuments((previous) =>
                      previous.filter((item) => item.id !== doc.id),
                    );
                    update((previous) => ({
                      ...previous,
                      recycled: [
                        { id: doc.id, title: doc.title, type: doc.type },
                        ...previous.recycled.filter(
                          (item) => item.id !== doc.id,
                        ),
                      ],
                    }));
                    activity(
                      "Document moved to recycle bin",
                      "Document",
                      doc.title,
                    );
                    setDeleteDoc(null);
                    undo(
                      "Document moved to recycle bin",
                      () => void restore(doc.id, doc.title),
                    );
                  })
                  .catch((problem) =>
                    setMutationError(
                      problem instanceof Error
                        ? problem.message
                        : "Deletion failed.",
                    ),
                  )
                  .finally(() => setMutationBusy(false));
              }}
            >
              {mutationBusy ? "Moving..." : "Move to recycle bin"}
            </button>
          </div>
        </Modal>
      )}
      {localClear && (
        <Modal
          title="Clear this browser workspace?"
          onClose={() => setLocalClear(false)}
        >
          <p>
            This removes this account’s local courses, notes, cards, chats,
            tasks, favorites and activity. Original documents remain in your
            vault.
          </p>
          <div className="ws-form-actions">
            <button className="secondary" onClick={() => setLocalClear(false)}>
              Cancel
            </button>
            <button
              className="danger-button"
              onClick={() => {
                controllers.current.forEach((controller) => controller.abort());
                update(() => emptyWorkspace());
                setLocalClear(false);
                setSpaceId(null);
                setChatSpace(null);
                toast("Browser workspace cleared.");
              }}
            >
              Clear browser data
            </button>
          </div>
        </Modal>
      )}
      {studyAttach && (
        <Modal title="Add source to Study" onClose={() => setStudyAttach(null)}>
          <div className="ws-form">
            <p>{documents.find((doc) => doc.id === studyAttach)?.title}</p>
            <label>
              Course
              <select
                value={attachCourse}
                onChange={(e) => setAttachCourse(e.target.value)}
              >
                <option value="">Create a course</option>
                {data.spaces.map((course) => (
                  <option key={course.id} value={course.id}>
                    {course.name}
                  </option>
                ))}
              </select>
            </label>
            {!attachCourse && (
              <label>
                Course name
                <input
                  value={newCourse}
                  maxLength={120}
                  onChange={(e) => setNewCourse(e.target.value)}
                />
              </label>
            )}
            <div className="ws-form-actions">
              <button
                className="primary"
                disabled={!attachCourse && !newCourse.trim()}
                onClick={() => {
                  const id = attachCourse || newId();
                  update((previous) => ({
                    ...previous,
                    spaces: attachCourse
                      ? previous.spaces.map((course) =>
                          course.id === id
                            ? {
                                ...course,
                                documentIds: [
                                  ...new Set([
                                    ...course.documentIds,
                                    studyAttach,
                                  ]),
                                ],
                              }
                            : course,
                        )
                      : [
                          ...previous.spaces,
                          {
                            id,
                            name: newCourse.trim(),
                            documentIds: [studyAttach],
                            createdAt: new Date().toISOString(),
                          },
                        ],
                  }));
                  setSpaceId(id);
                  setStudyAttach(null);
                  setNewCourse("");
                }}
              >
                Add source
              </button>
            </div>
          </div>
        </Modal>
      )}
    </main>
  );
}
