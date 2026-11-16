export type User = { id: string; email: string; displayName: string; isAdmin?: boolean };
export type SourcePage = { page: number | null; text: string };
export type VaultDocument = {
  id: string;
  title: string;
  type: string;
  date: string;
  pages: number;
  status: string;
  confidence: number;
  summary: string;
  rawText?: string;
  entities: { label: string; value: string }[];
  sourcePages?: SourcePage[];
};
export type Citation = {
  documentId: string;
  title: string;
  page: number | null;
  number?: number;
  excerpt: string;
};
export type Space = {
  id: string;
  name: string;
  documentIds: string[];
  createdAt: string;
};
export type Note = {
  id: string;
  spaceId: string;
  title: string;
  text: string;
  documentId: string;
  documentTitle: string;
  sourcePage: number | null;
  createdAt: string;
};
export type Card = {
  id: string;
  spaceId: string;
  front: string;
  back: string;
  documentId: string;
  documentTitle: string;
  sourcePage: number | null;
  sourceExcerpt: string;
  dueAt: string;
  intervalDays: number;
  reviews: number;
};
export type Question = {
  prompt: string;
  options: string[];
  correctIndex: number;
  explanation: string;
  sourceDocumentId: string;
  sourceTitle: string;
  sourceExcerpt: string;
  sourcePage: number | null;
  selectedIndex?: number;
};
export type Quiz = {
  id: string;
  documentId: string;
  spaceId: string;
  questions: Question[];
  createdAt: string;
};
export type Message = {
  id: string;
  role: "user" | "assistant";
  text: string;
  citations?: Citation[];
  saved?: boolean;
  error?: boolean;
  cancelled?: boolean;
};
export type Task = {
  id: string;
  title: string;
  due: string;
  priority: "High" | "Normal" | "Low";
  completed: boolean;
  documentId?: string;
  sourcePage?: number | null;
  excerpt?: string;
  importKey?: string;
};
export type Activity = {
  id: string;
  at: string;
  action: string;
  category:
    "Access" | "Document" | "Study" | "Security" | "AI Queries" | "Tasks";
  detail: string;
};
export type WorkspaceData = {
  spaces: Space[];
  notes: Note[];
  cards: Card[];
  quizzes: Record<string, Quiz>;
  chats: Record<string, Message[]>;
  tasks: Task[];
  favorites: string[];
  dismissedImports: string[];
  activity: Activity[];
  recycled: Pick<VaultDocument, "id" | "title" | "type">[];
};
export const emptyWorkspace = (): WorkspaceData => ({
  spaces: [],
  notes: [],
  cards: [],
  quizzes: {},
  chats: {},
  tasks: [],
  favorites: [],
  dismissedImports: [],
  activity: [],
  recycled: [],
});
export const newId = () => crypto.randomUUID();
export const categories = [
  "Document",
  "Study Material",
  "Lecture Notes",
  "Textbook & Reading",
  "Assignment & Coursework",
  "Exam & Past Paper",
  "Research & Report",
  "Academic Record",
  "Certificate & Qualification",
  "Application & Admission",
  "Funding Award Letter",
  "Bursary Agreement",
  "Fee Statement",
  "Bank Letter",
  "Appeal Correspondence",
  "Bank Statement",
  "Invoice & Receipt",
  "Budget & Financial Record",
  "Tax Document",
  "Identity & Personal Record",
  "CV & Cover Letter",
  "Employment & Work",
  "Contract & Agreement",
  "Housing & Property",
  "Medical & Health",
  "Insurance",
  "Travel & Immigration",
  "Letter & Correspondence",
  "Other",
];
export function sourcePages(doc: VaultDocument): SourcePage[] {
  return doc.sourcePages?.length
    ? doc.sourcePages.map((p) => ({
        page: p.page && p.page > 0 ? p.page : null,
        text: p.text,
      }))
    : [{ page: null, text: doc.rawText || "" }];
}
export function reviewCard(
  card: Card,
  recalled: boolean,
  now = new Date(),
): Card {
  const intervalDays = recalled
    ? Math.min(30, card.intervalDays ? card.intervalDays * 2 : 1)
    : 0;
  return {
    ...card,
    intervalDays,
    reviews: card.reviews + 1,
    dueAt: new Date(
      now.getTime() + (recalled ? intervalDays * 86400000 : 600000),
    ).toISOString(),
  };
}
export const dueCards = (cards: Card[], now = Date.now()) =>
  cards.filter((c) => !c.dueAt || new Date(c.dueAt).getTime() <= now);
export const dateValue = (date: Date) =>
  `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
export const today = () => dateValue(new Date());
export function shiftDate(date: string, days: number) {
  const value = new Date(`${date}T12:00:00`);
  value.setDate(value.getDate() + days);
  return dateValue(value);
}
export function quizProgress(quizzes: Quiz[]) {
  const answers = quizzes
    .flatMap((q) => q.questions)
    .filter((q) => q.selectedIndex !== undefined);
  return {
    answered: answers.length,
    correct: answers.filter((q) => q.selectedIndex === q.correctIndex).length,
    rounds: quizzes.length,
  };
}
export function answerQuestion(
  quiz: Quiz,
  questionIndex: number,
  selectedIndex: number,
): Quiz {
  if (
    !Number.isInteger(selectedIndex) ||
    selectedIndex < 0 ||
    selectedIndex > 3
  )
    return quiz;
  return {
    ...quiz,
    questions: quiz.questions.map((question, index) =>
      index !== questionIndex || question.selectedIndex !== undefined
        ? question
        : { ...question, selectedIndex },
    ),
  };
}
