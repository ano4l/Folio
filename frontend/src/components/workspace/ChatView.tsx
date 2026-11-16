import { useEffect, useRef, useState } from "react";
import {
  Send,
  Square,
  Copy,
  Volume2,
  Share2,
  Bookmark,
  Trash2,
  Download,
  Sparkles,
  RotateCcw,
  BookOpen,
  Layers3,
  Check,
  X,
  Mic,
  MicOff,
} from "lucide-react";
import { API_URL, api } from "./api";
import {
  newId,
  answerQuestion,
  type WorkspaceData,
  type VaultDocument,
  type Message,
  type Citation,
  type Quiz,
  type Question,
  type Card,
} from "./models";
import { download } from "./exports";
import type { Update, NoteSeed } from "./StudyView";
import { Empty, ErrorNotice, IconButton, Modal, PageHeader } from "./ui";
import { AnswerMarkdown } from "./AnswerMarkdown";
type Props = {
  data: WorkspaceData;
  update: Update;
  documents: VaultDocument[];
  documentId: string | null;
  spaceId: string | null;
  setContext: (doc: string | null, space?: string | null) => void;
  openDocument: (id: string, page?: number | null) => void;
  saveNote: (seed: NoteSeed) => void;
  toast: (message: string) => void;
  initialQuestion: string;
  consumeQuestion: () => void;
  activity: (
    action: string,
    category: "AI Queries" | "Study",
    detail: string,
  ) => void;
};
type StreamEvent = {
  type: "delta" | "replace" | "done" | "error";
  text?: string;
  citations?: Citation[];
  message?: string;
};
type Recognition = {
  lang: string;
  interimResults: boolean;
  start: () => void;
  stop: () => void;
  onresult:
    | ((event: {
        results: ArrayLike<ArrayLike<{ transcript: string }>>;
      }) => void)
    | null;
  onerror: (() => void) | null;
  onend: (() => void) | null;
};
export default function ChatView({
  data,
  update,
  documents,
  documentId,
  spaceId,
  setContext,
  openDocument,
  saveNote,
  toast,
  initialQuestion,
  consumeQuestion,
  activity,
}: Props) {
  const key = `${spaceId || "vault"}:${documentId || "all"}`;
  const [input, setInput] = useState(initialQuestion),
    [busy, setBusy] = useState<Record<string, boolean>>({}),
    [savedOnly, setSavedOnly] = useState(false),
    [error, setError] = useState("");
  const [quizSetup, setQuizSetup] = useState(false),
    [count, setCount] = useState(5),
    [difficulty, setDifficulty] = useState("standard"),
    [focus, setFocus] = useState("");
  const [quizBusy, setQuizBusy] = useState(false),
    [quizId, setQuizId] = useState<string | null>(null),
    [coverage, setCoverage] = useState("");
  const [quizExpanded, setQuizExpanded] = useState(true);
  const [clear, setClear] = useState(false),
    [retry, setRetry] = useState<number[] | null>(null),
    [cardQuestion, setCardQuestion] = useState<Question | null>(null),
    [cardSpace, setCardSpace] = useState(spaceId || data.spaces[0]?.id || ""),
    [courseName, setCourseName] = useState("");
  const controllers = useRef(
      new Map<string, { id: string; controller: AbortController }>(),
    ),
    quizController = useRef<AbortController | null>(null),
    log = useRef<HTMLDivElement>(null);
  const recognition = useRef<Recognition | null>(null),
    [listening, setListening] = useState(false);
  const messages = data.chats[key] || [];
  const doc = documents.find((d) => d.id === documentId);
  const available = spaceId
    ? documents.filter((d) =>
        data.spaces.find((s) => s.id === spaceId)?.documentIds.includes(d.id),
      )
    : documents;
  const quiz = quizId
    ? data.quizzes[quizId]
    : Object.values(data.quizzes)
        .filter(
          (q) => q.documentId === documentId && q.spaceId === (spaceId || ""),
        )
        .at(-1);
  const quizQuestions =
    quiz?.questions
      .map((question, index) => ({ question, index }))
      .filter((item) => !retry || retry.includes(item.index)) || [];
  const answered = quizQuestions.filter(
      (q) => q.question.selectedIndex !== undefined,
    ),
    correct = answered.filter(
      (q) => q.question.selectedIndex === q.question.correctIndex,
    ),
    completed =
      !!quizQuestions.length && answered.length === quizQuestions.length;
  const missed = quizQuestions
    .filter(
      (q) =>
        q.question.selectedIndex !== undefined &&
        q.question.selectedIndex !== q.question.correctIndex,
    )
    .map((q) => q.index);
  const quizMode = !!quiz && quizExpanded;
  useEffect(() => {
    setQuizExpanded(!completed);
  }, [quiz?.id, completed]);
  useEffect(() => {
    if (initialQuestion) {
      setInput(initialQuestion);
      consumeQuestion();
    }
  }, [initialQuestion, consumeQuestion]);
  useEffect(() => {
    log.current?.scrollTo({ top: log.current.scrollHeight });
  }, [messages.length, messages.at(-1)?.text, busy[key]]);
  useEffect(() => {
    setQuizId(null);
    setRetry(null);
    setError("");
    setSavedOnly(false);
    setCoverage("");
    quizController.current?.abort();
    setQuizBusy(false);
  }, [key]);
  useEffect(
    () => () => {
      controllers.current.forEach((request) => request.controller.abort());
      quizController.current?.abort();
      recognition.current?.stop();
      window.speechSynthesis?.cancel();
    },
    [],
  );
  const voiceInput = () => {
    if (recognition.current) {
      recognition.current.stop();
      recognition.current = null;
      setListening(false);
      return;
    }
    const browser = window as unknown as {
      SpeechRecognition?: new () => Recognition;
      webkitSpeechRecognition?: new () => Recognition;
    };
    const Constructor =
      browser.SpeechRecognition || browser.webkitSpeechRecognition;
    if (!Constructor) {
      toast("Voice input is unavailable here. Type your question instead.");
      return;
    }
    const session = new Constructor();
    session.lang = "en-ZA";
    session.interimResults = true;
    recognition.current = session;
    session.onresult = (event) => {
      if (recognition.current === session)
        setInput(
          Array.from(event.results)
            .map((result) => result[0].transcript)
            .join(" "),
        );
    };
    session.onerror = () => {
      if (recognition.current === session) {
        recognition.current = null;
        setListening(false);
        toast(
          "Voice permission or transcription is unavailable. Type your question instead.",
        );
      }
    };
    session.onend = () => {
      if (recognition.current === session) {
        recognition.current = null;
        setListening(false);
      }
    };
    try {
      session.start();
      setListening(true);
    } catch {
      recognition.current = null;
      setListening(false);
      toast("Unable to start voice input. Type your question instead.");
    }
  };
  const changeMessage = (
    conversation: string,
    id: string,
    edit: (message: Message) => Message,
  ) =>
    update((p) => ({
      ...p,
      chats: {
        ...p.chats,
        [conversation]: (p.chats[conversation] || []).map((message) =>
          message.id === id ? edit(message) : message,
        ),
      },
    }));
  const send = async (question = input) => {
    const text = question.trim();
    if (!text || controllers.current.has(key)) return;
    const conversation = key,
      id = newId(),
      requestId = newId(),
      controller = new AbortController();
    controllers.current.set(conversation, { id: requestId, controller });
    update((p) => ({
      ...p,
      chats: {
        ...p.chats,
        [conversation]: [
          ...(p.chats[conversation] || []),
          { id: newId(), role: "user", text },
          { id, role: "assistant", text: "" },
        ],
      },
    }));
    setInput("");
    setError("");
    setBusy((p) => ({ ...p, [conversation]: true }));
    const current = () =>
      controllers.current.get(conversation)?.id === requestId &&
      !controller.signal.aborted;
    let textAnswer = "",
      doneSeen = false;
    const process = (line: string) => {
      if (!line.trim() || !current()) return;
      const event = JSON.parse(line) as StreamEvent;
      if (event.type === "error")
        throw new Error(event.message || "The answer could not be completed.");
      if (event.type === "delta" || event.type === "replace") {
        textAnswer =
          event.type === "replace"
            ? event.text || ""
            : textAnswer + (event.text || "");
        changeMessage(conversation, id, (message) => ({
          ...message,
          text: textAnswer,
        }));
      }
      if (event.type === "done") {
        doneSeen = true;
        changeMessage(conversation, id, (message) => ({
          ...message,
          citations: (event.citations || []).map((c) => ({
            ...c,
            documentId: String(c.documentId),
            page: typeof c.page === "number" && c.page > 0 ? c.page : null,
            excerpt: c.excerpt || "",
          })),
        }));
      }
    };
    try {
      const response = await fetch(`${API_URL}/v1/ai/ask`, {
        method: "POST",
        credentials: "include",
        signal: controller.signal,
        headers: {
          "Content-Type": "application/json",
          "X-Requested-With": "FolioWeb",
        },
        body: JSON.stringify({
          question: text,
          documentId,
          history: messages
            .filter((m) => !m.error && !m.cancelled)
            .slice(-10)
            .map(({ role, text }) => ({ role, text })),
        }),
      });
      if (!response.ok || !response.body) {
        const details = await response.json().catch(() => ({}));
        throw new Error(
          details.message || "The assistant could not answer right now.",
        );
      }
      const reader = response.body.getReader(),
        decoder = new TextDecoder();
      let pending = "";
      while (current()) {
        const { done, value } = await reader.read();
        pending += decoder.decode(value || new Uint8Array(), { stream: !done });
        const lines = pending.split("\n");
        pending = lines.pop() || "";
        for (const line of lines) process(line);
        if (done) {
          process(pending);
          break;
        }
      }
      if (current() && (!doneSeen || !textAnswer.trim()))
        throw new Error(
          "The connection ended before the answer finished. Please retry.",
        );
      if (current())
        activity(
          "Document question answered",
          "AI Queries",
          doc?.title || "Vault sources",
        );
    } catch (problem) {
      if (!current()) return;
      const message =
        problem instanceof Error
          ? problem.message
          : "Unable to complete this answer.";
      changeMessage(conversation, id, (item) => ({
        ...item,
        text: textAnswer || message,
        error: true,
      }));
      setError(message);
    } finally {
      if (controllers.current.get(conversation)?.id === requestId) {
        controllers.current.delete(conversation);
        setBusy((p) => ({ ...p, [conversation]: false }));
      }
    }
  };
  const cancel = () => {
    const request = controllers.current.get(key);
    request?.controller.abort();
    controllers.current.delete(key);
    setBusy((p) => ({ ...p, [key]: false }));
    const last = messages.at(-1);
    if (last?.role === "assistant")
      changeMessage(key, last.id, (item) => ({
        ...item,
        text: item.text || "Answer cancelled.",
        cancelled: true,
      }));
  };
  const generate = async () => {
    if (!documentId || quizBusy) return;
    const controller = new AbortController();
    quizController.current?.abort();
    quizController.current = controller;
    setQuizBusy(true);
    setError("");
    try {
      const result = await api<{
        questions: Question[];
        requestedCount?: number;
        coverage?: string;
      }>(
        "ai/quiz",
        { documentId, count, difficulty, focus: focus.trim() },
        controller.signal,
      );
      if (quizController.current !== controller || controller.signal.aborted)
        return;
      if (
        !result.questions?.length ||
        result.questions.some(
          (q) =>
            q.options?.length !== 4 ||
            q.correctIndex < 0 ||
            q.correctIndex > 3 ||
            q.sourceDocumentId !== documentId,
        )
      )
        throw new Error(
          "The quiz returned incomplete source information. Please try again.",
        );
      const generated: Quiz = {
        id: newId(),
        documentId,
        spaceId: spaceId || "",
        questions: result.questions.map((q) => ({
          ...q,
          sourcePage: q.sourcePage && q.sourcePage > 0 ? q.sourcePage : null,
        })),
        createdAt: new Date().toISOString(),
      };
      update((p) => ({
        ...p,
        quizzes: { ...p.quizzes, [generated.id]: generated },
      }));
      setQuizId(generated.id);
      setQuizSetup(false);
      setRetry(null);
      setCoverage(
        result.questions.length < count
          ? `${result.questions.length} grounded questions available from this source (${count} requested).`
          : "",
      );
      activity(
        "Practice quiz generated",
        "Study",
        `${doc?.title || "Source"}: ${generated.questions.length} questions`,
      );
    } catch (problem) {
      if (!controller.signal.aborted)
        setError(
          problem instanceof Error
            ? problem.message
            : "Quiz could not be generated.",
        );
    } finally {
      if (quizController.current === controller) {
        quizController.current = null;
        setQuizBusy(false);
      }
    }
  };
  const saveCard = () => {
    if (!cardQuestion) return;
    let destination = cardSpace;
    if (!destination && !courseName.trim()) return;
    if (!destination) destination = newId();
    const card: Card = {
      id: newId(),
      spaceId: destination,
      front: cardQuestion.prompt,
      back: `${cardQuestion.options[cardQuestion.correctIndex]}\n\n${cardQuestion.explanation}`,
      documentId: cardQuestion.sourceDocumentId,
      documentTitle: cardQuestion.sourceTitle,
      sourcePage: cardQuestion.sourcePage,
      sourceExcerpt: cardQuestion.sourceExcerpt,
      dueAt: "",
      intervalDays: 0,
      reviews: 0,
    };
    update((p) => ({
      ...p,
      spaces: cardSpace
        ? p.spaces
        : [
            ...p.spaces,
            {
              id: destination,
              name: courseName.trim(),
              documentIds: [card.documentId],
              createdAt: new Date().toISOString(),
            },
          ],
      cards: [...p.cards, card],
    }));
    setCardQuestion(null);
    toast("Question saved as a revision card.");
  };
  const copy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      toast("Copied.");
    } catch {
      toast("Clipboard unavailable. Select the answer to copy it.");
    }
  };
  const share = async (text: string) => {
    try {
      if (navigator.share)
        await navigator.share({ title: "Folio answer", text });
      else await copy(text);
    } catch (problem) {
      if (!(problem instanceof DOMException && problem.name === "AbortError"))
        toast("Sharing is unavailable. Copy the answer instead.");
    }
  };
  return (
    <section className="ws-view ws-chat-view">
      <PageHeader
        title={spaceId ? "Study chat" : "Ask AI"}
        subtitle={doc?.title || "Answers grounded in your vault."}
      >
        <IconButton
          label="Export conversation"
          onClick={() =>
            download(
              new Blob(
                [
                  messages
                    .map(
                      (m) =>
                        `## ${m.role === "user" ? "You" : "Folio"}\n\n${m.text}\n${(m.citations || []).map((c) => `Source: ${c.title}${c.page ? `, page ${c.page}` : " (page unavailable)"}\n${c.excerpt}`).join("\n")}`,
                    )
                    .join("\n\n"),
                ],
                { type: "text/markdown" },
              ),
              "Folio conversation.md",
            )
          }
        >
          <Download size={18} />
        </IconButton>
        <IconButton
          label="Clear conversation"
          onClick={() => setClear(true)}
          disabled={!messages.length}
        >
          <Trash2 size={18} />
        </IconButton>
      </PageHeader>
      <div className="ws-chat-context">
        <label>
          Source
          <select
            value={documentId || ""}
            onChange={(e) => setContext(e.target.value || null, spaceId)}
          >
            <option value="">All vault documents</option>
            {available.map((d) => (
              <option key={d.id} value={d.id}>
                {d.title}
              </option>
            ))}
          </select>
        </label>
        <button
          className={`secondary ${savedOnly ? "selected" : ""}`}
          aria-pressed={savedOnly}
          onClick={() => setSavedOnly(!savedOnly)}
        >
          <Bookmark size={15} />
          Saved answers
        </button>
        <button
          className="primary"
          disabled={!doc || doc.status !== "Ready"}
          onClick={() => setQuizSetup(true)}
        >
          <Sparkles size={15} />
          Practice quiz
        </button>
      </div>
      <ErrorNotice message={error} />
      {quiz && (
        <section
          className="ws-quiz"
          aria-label="Practice quiz"
          id="ws-practice-quiz"
        >
          <header className="ws-row">
            <div>
              <h2>{retry ? "Retry missed questions" : "Practice quiz"}</h2>
              <p>
                {answered.length}/{quizQuestions.length} answered
                {answered.length ? ` · ${correct.length} correct` : ""}
              </p>
            </div>
            <div className="ws-actions">
              <button
                className="secondary"
                aria-expanded={quizExpanded}
                onClick={() => setQuizExpanded((value) => !value)}
              >
                {quizExpanded
                  ? "Return to chat"
                  : completed
                    ? "Review questions"
                    : "Resume quiz"}
              </button>
              <button className="secondary" onClick={() => setQuizSetup(true)}>
                <Sparkles size={15} />
                New quiz
              </button>
            </div>
          </header>
          {coverage && <p className="ws-notice">{coverage}</p>}
          {quizExpanded &&
            quizQuestions.map(({ question, index }, visibleIndex) => (
              <article className="ws-question" key={`${quiz.id}:${index}`}>
                <span className="ws-category">Question {visibleIndex + 1}</span>
                <h3>{question.prompt}</h3>
                <div className="ws-options">
                  {question.options.map((option, optionIndex) => (
                    <button
                      key={optionIndex}
                      disabled={question.selectedIndex !== undefined}
                      className={
                        question.selectedIndex === undefined
                          ? ""
                          : optionIndex === question.correctIndex
                            ? "correct"
                            : optionIndex === question.selectedIndex
                              ? "incorrect"
                              : ""
                      }
                      onClick={() =>
                        update((p) => ({
                          ...p,
                          quizzes: {
                            ...p.quizzes,
                            [quiz.id]: answerQuestion(
                              p.quizzes[quiz.id],
                              index,
                              optionIndex,
                            ),
                          },
                        }))
                      }
                    >
                      <span>{String.fromCharCode(65 + optionIndex)}</span>
                      {option}
                      {question.selectedIndex !== undefined &&
                        optionIndex === question.correctIndex && (
                          <Check size={17} />
                        )}
                      {question.selectedIndex === optionIndex &&
                        optionIndex !== question.correctIndex && (
                          <X size={17} />
                        )}
                    </button>
                  ))}
                </div>
                {question.selectedIndex !== undefined && (
                  <div className="ws-question-feedback">
                    <b>
                      {question.selectedIndex === question.correctIndex
                        ? "Correct"
                        : "Not quite"}
                    </b>
                    <p>{question.explanation}</p>
                    {question.sourceExcerpt && (
                      <blockquote>{question.sourceExcerpt}</blockquote>
                    )}
                    <div className="ws-row">
                      <button
                        className="ws-source-link"
                        onClick={() =>
                          openDocument(
                            question.sourceDocumentId,
                            question.sourcePage,
                          )
                        }
                      >
                        <BookOpen size={14} />
                        {question.sourceTitle}
                        {question.sourcePage
                          ? ` · Page ${question.sourcePage}`
                          : " · Page unavailable"}
                      </button>
                      <button
                        className="secondary"
                        onClick={() => {
                          setCardQuestion(question);
                          setCardSpace(spaceId || data.spaces[0]?.id || "");
                        }}
                      >
                        <Layers3 size={15} />
                        Save card
                      </button>
                    </div>
                  </div>
                )}
              </article>
            ))}
          {completed && (
            <div className="ws-quiz-score">
              <b>
                Quiz complete · {correct.length}/{quizQuestions.length} correct
              </b>
              {missed.length > 0 && (
                <button
                  className="secondary"
                  onClick={() => {
                    update((p) => ({
                      ...p,
                      quizzes: {
                        ...p.quizzes,
                        [quiz.id]: {
                          ...p.quizzes[quiz.id],
                          questions: p.quizzes[quiz.id].questions.map((q, i) =>
                            missed.includes(i)
                              ? { ...q, selectedIndex: undefined }
                              : q,
                          ),
                        },
                      },
                    }));
                    setRetry(missed);
                    setQuizExpanded(true);
                  }}
                >
                  <RotateCcw size={15} />
                  Retry missed ({missed.length})
                </button>
              )}
            </div>
          )}
        </section>
      )}
      {!quizMode && (
        <div className="ws-chat-log" ref={log} aria-live="polite">
          {messages.length === 0 && (
            <Empty title="Start with a question">
              Choose a document to explore its concepts and check the original
              source.
            </Empty>
          )}
          {messages
            .filter((m) => !savedOnly || m.saved)
            .map((message, index) => (
              <article
                className={`ws-message ${message.role}`}
                key={message.id}
              >
                <small>{message.role === "user" ? "You" : "Folio"}</small>
                <div
                  className={`ws-answer-text ${message.role === "assistant" ? "ws-answer-markdown" : ""}`}
                >
                  {message.role === "assistant" ? (
                    <AnswerMarkdown
                      text={
                        message.text ||
                        (busy[key] ? "Reading your sources..." : "")
                      }
                      citations={message.citations}
                      openSource={openDocument}
                    />
                  ) : (
                    message.text
                  )}
                </div>
                {message.citations?.map((citation, i) => (
                  <button
                    key={`${citation.documentId}:${i}`}
                    className="ws-citation"
                    onClick={() =>
                      openDocument(citation.documentId, citation.page)
                    }
                  >
                    <BookOpen size={14} />
                    <span>
                      {citation.number ? `[${citation.number}] ` : ""}
                      {citation.title}
                      {citation.page
                        ? ` · Page ${citation.page}`
                        : " · Page unavailable"}
                      {citation.excerpt && <small>{citation.excerpt}</small>}
                    </span>
                  </button>
                ))}
                {message.role === "assistant" && message.text && !busy[key] && (
                  <div className="ws-message-actions">
                    <IconButton
                      label="Copy answer"
                      onClick={() => void copy(message.text)}
                    >
                      <Copy size={15} />
                    </IconButton>
                    <IconButton
                      label="Share answer"
                      onClick={() => void share(message.text)}
                    >
                      <Share2 size={15} />
                    </IconButton>
                    <IconButton
                      label="Read answer aloud"
                      onClick={() => {
                        if (!window.speechSynthesis) {
                          toast("Read aloud is unavailable in this browser.");
                          return;
                        }
                        window.speechSynthesis.cancel();
                        window.speechSynthesis.speak(
                          new SpeechSynthesisUtterance(message.text),
                        );
                      }}
                    >
                      <Volume2 size={15} />
                    </IconButton>
                    <IconButton
                      label={message.saved ? "Unsave answer" : "Save answer"}
                      onClick={() =>
                        changeMessage(key, message.id, (m) => ({
                          ...m,
                          saved: !m.saved,
                        }))
                      }
                    >
                      <Bookmark
                        size={15}
                        fill={message.saved ? "currentColor" : "none"}
                      />
                    </IconButton>
                    {!!message.citations?.length &&
                      !message.error &&
                      !message.cancelled && (
                        <button
                          className="link"
                          onClick={() => {
                            const citation = message.citations![0];
                            saveNote({
                              text: message.text,
                              documentId: citation.documentId,
                              documentTitle: citation.title,
                              sourcePage: citation.page,
                              spaceId: spaceId || undefined,
                            });
                          }}
                        >
                          <Bookmark size={14} />
                          Save note
                        </button>
                      )}
                    {(message.error || message.cancelled) && (
                      <button
                        className="link"
                        onClick={() => {
                          const question = [...messages.slice(0, index)]
                            .reverse()
                            .find((m) => m.role === "user");
                          if (question) void send(question.text);
                        }}
                      >
                        <RotateCcw size={14} />
                        Retry
                      </button>
                    )}
                  </div>
                )}
              </article>
            ))}
          {savedOnly && !messages.some((m) => m.saved) && (
            <Empty title="No saved answers yet" />
          )}
        </div>
      )}
      {!quizMode && (
        <div className="ws-chat-bottom">
          <div className="ws-quick-actions">
            {["Explain simply", "Teach step by step", "Summarise"].map(
              (mode) => (
                <button
                  className="secondary"
                  key={mode}
                  disabled={!!busy[key]}
                  onClick={() =>
                    void send(
                      `${mode}: ${input.trim() || (doc ? "the main concepts in this document" : "the documents in my vault")}`,
                    )
                  }
                >
                  {mode}
                </button>
              ),
            )}
          </div>
          <form
            className="ws-chat-composer"
            onSubmit={(e) => {
              e.preventDefault();
              void send();
            }}
          >
            <textarea
              value={input}
              onChange={(e) => setInput(e.target.value)}
              rows={2}
              aria-label="Your question"
              placeholder={
                doc ? "Ask about this source..." : "Ask about your documents..."
              }
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  void send();
                }
              }}
            />
            <IconButton
              label={listening ? "Stop voice input" : "Voice input"}
              onClick={voiceInput}
            >
              {listening ? <MicOff size={18} /> : <Mic size={18} />}
            </IconButton>
            {busy[key] ? (
              <IconButton label="Cancel answer" onClick={cancel}>
                <Square size={18} />
              </IconButton>
            ) : (
              <button
                className="primary"
                type="submit"
                aria-label="Send question"
                title="Send question"
                disabled={!input.trim()}
              >
                <Send size={18} />
              </button>
            )}
          </form>
        </div>
      )}
      {quizSetup && (
        <Modal
          title="Set up your quiz"
          onClose={() => {
            quizController.current?.abort();
            setQuizSetup(false);
            setQuizBusy(false);
          }}
        >
          <div className="ws-form">
            <p>{doc?.title}</p>
            <label>
              Questions
              <select value={count} onChange={(e) => setCount(+e.target.value)}>
                <option value={3}>3 questions</option>
                <option value={5}>5 questions</option>
                <option value={8}>8 questions</option>
              </select>
            </label>
            <label>
              Difficulty
              <select
                value={difficulty}
                onChange={(e) => setDifficulty(e.target.value)}
              >
                <option value="foundation">Foundation</option>
                <option value="standard">Standard</option>
                <option value="challenge">Challenge</option>
              </select>
            </label>
            <label>
              Focus (optional)
              <input
                value={focus}
                maxLength={200}
                onChange={(e) => setFocus(e.target.value)}
                placeholder="e.g. transactions and joins"
              />
            </label>
            <ErrorNotice message={error} />
            <div className="ws-form-actions">
              <button
                className="secondary"
                onClick={() => {
                  quizController.current?.abort();
                  setQuizSetup(false);
                  setQuizBusy(false);
                }}
              >
                Cancel
              </button>
              <button
                className="primary"
                disabled={quizBusy}
                onClick={() => void generate()}
              >
                <Sparkles size={16} />
                {quizBusy ? "Building grounded questions..." : "Generate quiz"}
              </button>
            </div>
          </div>
        </Modal>
      )}
      {clear && (
        <Modal title="Clear this conversation?" onClose={() => setClear(false)}>
          <p>Saved study notes and revision cards will remain.</p>
          <div className="ws-form-actions">
            <button className="secondary" onClick={() => setClear(false)}>
              Cancel
            </button>
            <button
              className="danger-button"
              onClick={() => {
                cancel();
                update((p) => ({ ...p, chats: { ...p.chats, [key]: [] } }));
                setClear(false);
              }}
            >
              Clear conversation
            </button>
          </div>
        </Modal>
      )}
      {cardQuestion && (
        <Modal title="Save revision card" onClose={() => setCardQuestion(null)}>
          <div className="ws-form">
            <p>{cardQuestion.prompt}</p>
            <label>
              Course
              <select
                value={cardSpace}
                onChange={(e) => setCardSpace(e.target.value)}
              >
                <option value="">Create a course</option>
                {data.spaces.map((s) => (
                  <option value={s.id} key={s.id}>
                    {s.name}
                  </option>
                ))}
              </select>
            </label>
            {!cardSpace && (
              <label>
                Course name
                <input
                  required
                  value={courseName}
                  onChange={(e) => setCourseName(e.target.value)}
                />
              </label>
            )}
            <div className="ws-form-actions">
              <button
                className="primary"
                disabled={!cardSpace && !courseName.trim()}
                onClick={saveCard}
              >
                Save card
              </button>
            </div>
          </div>
        </Modal>
      )}
    </section>
  );
}
