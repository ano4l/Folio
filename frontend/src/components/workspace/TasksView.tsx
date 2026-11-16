import { useMemo, useState } from "react";
import {
  Plus,
  Pencil,
  Trash2,
  Check,
  RotateCcw,
  CalendarDays,
  List,
  Download,
  ChevronLeft,
  ChevronRight,
  BookOpen,
  CalendarPlus,
} from "lucide-react";
import {
  newId,
  today,
  shiftDate,
  dateValue,
  type Task,
  type VaultDocument,
  type WorkspaceData,
} from "./models";
import { extractDeadlines, type DeadlineCandidate } from "./deadlines";
import { calendarExport, download } from "./exports";
import type { Update } from "./StudyView";
import { Empty, IconButton, Modal, PageHeader } from "./ui";
export function TaskEditor({
  task,
  documentId,
  documents,
  onSave,
  onClose,
}: {
  task?: Task;
  documentId?: string;
  documents: VaultDocument[];
  onSave: (task: Task) => void;
  onClose: () => void;
}) {
  const [title, setTitle] = useState(task?.title || ""),
    [due, setDue] = useState(task?.due || today()),
    [priority, setPriority] = useState<Task["priority"]>(
      task?.priority || "Normal",
    ),
    [docId, setDocId] = useState(task?.documentId || documentId || "");
  return (
    <Modal title={task ? "Edit task" : "New task"} onClose={onClose}>
      <form
        className="ws-form"
        onSubmit={(event) => {
          event.preventDefault();
          onSave({
            ...task,
            id: task?.id || newId(),
            title: title.trim(),
            due,
            priority,
            completed: task?.completed || false,
            documentId: docId || undefined,
            ...(docId !== task?.documentId
              ? { sourcePage: undefined, excerpt: undefined }
              : {}),
          });
          onClose();
        }}
      >
        <label>
          Task
          <input
            required
            value={title}
            maxLength={200}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="What needs to be done?"
          />
        </label>
        <label>
          Due date
          <input
            type="date"
            required
            value={due}
            onChange={(e) => setDue(e.target.value)}
          />
        </label>
        <label>
          Priority
          <select
            value={priority}
            onChange={(e) => setPriority(e.target.value as Task["priority"])}
          >
            <option>High</option>
            <option>Normal</option>
            <option>Low</option>
          </select>
        </label>
        <label>
          Source document
          <select value={docId} onChange={(e) => setDocId(e.target.value)}>
            <option value="">Personal task</option>
            {documents.map((doc) => (
              <option value={doc.id} key={doc.id}>
                {doc.title}
              </option>
            ))}
          </select>
        </label>
        <div className="ws-form-actions">
          <button type="button" className="secondary" onClick={onClose}>
            Cancel
          </button>
          <button className="primary" type="submit">
            <Check size={15} />
            Save task
          </button>
        </div>
      </form>
    </Modal>
  );
}
type Props = {
  data: WorkspaceData;
  update: Update;
  documents: VaultDocument[];
  openDocument: (id: string, page?: number | null) => void;
  undo: (message: string, restore: () => void) => void;
  activity: (action: string, detail: string) => void;
};
export default function TasksView({
  data,
  update,
  documents,
  openDocument,
  undo,
  activity,
}: Props) {
  const [query, setQuery] = useState(""),
    [highOnly, setHighOnly] = useState(false),
    [view, setView] = useState<"list" | "calendar">("list"),
    [month, setMonth] = useState(
      new Date(new Date().getFullYear(), new Date().getMonth(), 1),
    ),
    [selectedDate, setSelectedDate] = useState<string | null>(null),
    [completedOpen, setCompletedOpen] = useState(false),
    [edit, setEdit] = useState<Task | "new" | null>(null),
    [review, setReview] = useState<DeadlineCandidate | null>(null),
    [reviewDate, setReviewDate] = useState(today()),
    [importsOpen, setImportsOpen] = useState(false);
  const candidates = useMemo(
    () =>
      extractDeadlines(documents).filter(
        (candidate) =>
          !data.dismissedImports.includes(candidate.key) &&
          !data.tasks.some((task) => task.importKey === candidate.key),
      ),
    [documents, data.dismissedImports, data.tasks],
  );
  const filtered = data.tasks.filter(
    (task) =>
      `${task.title} ${documents.find((d) => d.id === task.documentId)?.title || ""} ${task.excerpt || ""}`
        .toLowerCase()
        .includes(query.toLowerCase()) &&
      (!highOnly || task.priority === "High"),
  );
  const active = filtered
      .filter((t) => !t.completed && (!selectedDate || t.due === selectedDate))
      .sort((a, b) => a.due.localeCompare(b.due)),
    complete = filtered.filter((t) => t.completed);
  const save = (task: Task) => {
    update((p) => ({
      ...p,
      tasks: p.tasks.some((t) => t.id === task.id)
        ? p.tasks.map((t) => (t.id === task.id ? task : t))
        : [...p.tasks, task],
    }));
    activity("Task saved", task.title);
  };
  const toggle = (task: Task) => {
    update((p) => ({
      ...p,
      tasks: p.tasks.map((t) =>
        t.id === task.id ? { ...t, completed: !t.completed } : t,
      ),
    }));
    activity(task.completed ? "Task reopened" : "Task completed", task.title);
  };
  const importCandidate = (candidate: DeadlineCandidate, due: string) => {
    save({
      id: newId(),
      title: candidate.action,
      due,
      priority: "Normal",
      completed: false,
      documentId: candidate.documentId,
      sourcePage: candidate.page,
      excerpt: candidate.excerpt,
      importKey: candidate.key,
    });
  };
  const renderTask = (task: Task) => (
    <article
      key={task.id}
      className={`ws-task ${task.completed ? "completed" : ""}`}
    >
      <IconButton
        label={
          task.completed ? `Reopen ${task.title}` : `Complete ${task.title}`
        }
        onClick={() => toggle(task)}
      >
        <span className={`ws-task-check ${task.completed ? "checked" : ""}`}>
          {task.completed && <Check size={16} />}
        </span>
      </IconButton>
      <div className="ws-task-content">
        <h3>{task.title}</h3>
        <p>
          <span className={`ws-priority ${task.priority.toLowerCase()}`}>
            {task.priority}
          </span>
          <span
            className={
              !task.completed && task.due < today() ? "ws-overdue" : ""
            }
          >
            {new Date(`${task.due}T12:00:00`).toLocaleDateString("en-ZA", {
              day: "numeric",
              month: "short",
              year: "numeric",
            })}
            {!task.completed && task.due < today() ? " · Overdue" : ""}
          </span>
        </p>
        {task.documentId && (
          <button
            className="ws-source-link"
            onClick={() => openDocument(task.documentId!, task.sourcePage)}
          >
            <BookOpen size={13} />
            {documents.find((d) => d.id === task.documentId)?.title ||
              "Source unavailable"}
            {task.sourcePage ? ` · Page ${task.sourcePage}` : ""}
          </button>
        )}
        {task.excerpt && (
          <details>
            <summary>Source excerpt</summary>
            <blockquote>{task.excerpt}</blockquote>
          </details>
        )}
      </div>
      <div className="ws-task-actions">
        <IconButton label="Edit task" onClick={() => setEdit(task)}>
          <Pencil size={16} />
        </IconButton>
        <IconButton
          label="Postpone one day"
          disabled={task.completed}
          onClick={() => save({ ...task, due: shiftDate(task.due, 1) })}
        >
          <CalendarPlus size={16} />
        </IconButton>
        <IconButton
          label="Delete task"
          onClick={() => {
            update((p) => ({
              ...p,
              tasks: p.tasks.filter((t) => t.id !== task.id),
              dismissedImports: task.importKey
                ? [...new Set([...p.dismissedImports, task.importKey])]
                : p.dismissedImports,
            }));
            undo("Task deleted", () =>
              update((p) => ({
                ...p,
                tasks: [...p.tasks, task],
                dismissedImports: p.dismissedImports.filter(
                  (key) => key !== task.importKey,
                ),
              })),
            );
          }}
        >
          <Trash2 size={16} />
        </IconButton>
      </div>
    </article>
  );
  const calendarDays = new Date(
      month.getFullYear(),
      month.getMonth() + 1,
      0,
    ).getDate(),
    calendarPadding = (month.getDay() + 6) % 7;
  return (
    <section className="ws-view">
      <PageHeader
        title="Deadlines"
        subtitle={`${data.tasks.filter((t) => !t.completed).length} tasks to do`}
      >
        <button
          className="secondary"
          onClick={() =>
            download(
              new Blob([calendarExport(data.tasks)], { type: "text/calendar" }),
              "Folio tasks.ics",
            )
          }
        >
          <Download size={15} />
          Calendar
        </button>
        <button className="primary" onClick={() => setEdit("new")}>
          <Plus size={16} />
          New task
        </button>
      </PageHeader>
      <div className="ws-toolbar">
        <input
          className="ws-search"
          aria-label="Search tasks"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search tasks"
        />
        <label className="ws-check">
          <input
            type="checkbox"
            checked={highOnly}
            onChange={(e) => setHighOnly(e.target.checked)}
          />
          High priority
        </label>
        <div className="ws-tabs compact" role="tablist" aria-label="Task view">
          <button
            role="tab"
            aria-selected={view === "list"}
            className={view === "list" ? "active" : ""}
            onClick={() => {
              setView("list");
              setSelectedDate(null);
            }}
          >
            <List size={16} />
            List
          </button>
          <button
            role="tab"
            aria-selected={view === "calendar"}
            className={view === "calendar" ? "active" : ""}
            onClick={() => setView("calendar")}
          >
            <CalendarDays size={16} />
            Calendar
          </button>
        </div>
      </div>
      {candidates.length > 0 && (
        <div className="ws-import-notice">
          <div>
            <b>{candidates.length} source dates to review</b>
            <p>Confirm document deadlines before adding them.</p>
          </div>
          <button
            className="secondary"
            onClick={() => setImportsOpen(!importsOpen)}
          >
            {importsOpen ? "Hide dates" : "Review dates"}
          </button>
        </div>
      )}
      {importsOpen &&
        candidates.map((candidate) => (
          <article className="ws-import" key={candidate.key}>
            <div>
              <h3>
                {candidate.action} · {candidate.dateText}
              </h3>
              <p>
                {candidate.title}
                {candidate.page
                  ? ` · Page ${candidate.page}`
                  : " · Page unavailable"}
              </p>
              <blockquote>{candidate.excerpt}</blockquote>
              <span
                className={candidate.due ? "ws-category" : "ws-review-needed"}
              >
                {candidate.due ? "Explicit date" : "Date needs confirmation"}
              </span>
            </div>
            <div className="ws-actions">
              <button
                className="primary"
                onClick={() => {
                  if (candidate.due) importCandidate(candidate, candidate.due);
                  else {
                    setReview(candidate);
                    setReviewDate(today());
                  }
                }}
              >
                {candidate.due ? "Add task" : "Choose date"}
              </button>
              <button
                className="secondary"
                onClick={() => {
                  update((p) => ({
                    ...p,
                    dismissedImports: [...p.dismissedImports, candidate.key],
                  }));
                  undo("Source date dismissed", () =>
                    update((p) => ({
                      ...p,
                      dismissedImports: p.dismissedImports.filter(
                        (key) => key !== candidate.key,
                      ),
                    })),
                  );
                }}
              >
                Dismiss
              </button>
            </div>
          </article>
        ))}
      {view === "calendar" && (
        <div className="ws-calendar">
          <header>
            <IconButton
              label="Previous month"
              onClick={() =>
                setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))
              }
            >
              <ChevronLeft size={17} />
            </IconButton>
            <h2>
              {month.toLocaleDateString("en-ZA", {
                month: "long",
                year: "numeric",
              })}
            </h2>
            <button
              className="link"
              onClick={() => {
                setMonth(
                  new Date(new Date().getFullYear(), new Date().getMonth(), 1),
                );
                setSelectedDate(today());
              }}
            >
              Today
            </button>
            <IconButton
              label="Next month"
              onClick={() =>
                setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))
              }
            >
              <ChevronRight size={17} />
            </IconButton>
          </header>
          <div className="ws-calendar-grid">
            {["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map((day) => (
              <span className="ws-weekday" key={day}>
                {day}
              </span>
            ))}
            {Array.from({ length: calendarPadding }, (_, i) => (
              <span key={`padding${i}`} />
            ))}
            {Array.from({ length: calendarDays }, (_, index) => {
              const value = dateValue(
                  new Date(month.getFullYear(), month.getMonth(), index + 1),
                ),
                tasks = filtered.filter((t) => !t.completed && t.due === value);
              return (
                <button
                  key={value}
                  className={`${value === today() ? "today" : ""} ${selectedDate === value ? "selected" : ""}`}
                  onClick={() =>
                    setSelectedDate(selectedDate === value ? null : value)
                  }
                  aria-label={`${value}, ${tasks.length} tasks`}
                >
                  <b>{index + 1}</b>
                  {tasks.length > 0 && (
                    <span>
                      {tasks.length}
                      <small> tasks</small>
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        </div>
      )}
      {selectedDate && (
        <div className="ws-row ws-date-heading">
          <h3>
            {new Date(`${selectedDate}T12:00:00`).toLocaleDateString("en-ZA", {
              dateStyle: "long",
            })}
          </h3>
          <button className="link" onClick={() => setSelectedDate(null)}>
            Show all
          </button>
        </div>
      )}
      {active.length ? (
        <div className="ws-task-list">{active.map(renderTask)}</div>
      ) : (
        <Empty
          title={
            selectedDate
              ? "No tasks on this date"
              : query || highOnly
                ? "No matching tasks"
                : "You’re all caught up"
          }
        />
      )}
      {complete.length > 0 && (
        <div className="ws-completed">
          <button
            className="link"
            onClick={() => setCompletedOpen(!completedOpen)}
            aria-expanded={completedOpen}
          >
            <Check size={15} />
            Completed ({complete.length})
          </button>
          {completedOpen && complete.map(renderTask)}
        </div>
      )}
      {edit && (
        <TaskEditor
          task={edit === "new" ? undefined : edit}
          documents={documents}
          onSave={save}
          onClose={() => setEdit(null)}
        />
      )}
      {review && (
        <Modal
          title="Confirm the deadline date"
          onClose={() => setReview(null)}
        >
          <div className="ws-form">
            <p>
              The source says “{review.dateText}”. Its year, ordering or example
              context needs your review.
            </p>
            <blockquote>{review.excerpt}</blockquote>
            <label>
              Confirmed date
              <input
                type="date"
                required
                value={reviewDate}
                onChange={(e) => setReviewDate(e.target.value)}
              />
            </label>
            <div className="ws-form-actions">
              <button className="secondary" onClick={() => setReview(null)}>
                Cancel
              </button>
              <button
                className="primary"
                disabled={!reviewDate}
                onClick={() => {
                  importCandidate(review, reviewDate);
                  setReview(null);
                }}
              >
                Add confirmed task
              </button>
            </div>
          </div>
        </Modal>
      )}
    </section>
  );
}
