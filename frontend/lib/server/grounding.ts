const STOP_WORDS = new Set(["the","a","an","and","or","is","are","was","were","to","of","in","on","for","my","me","i","it","that","this","what","when","how","can","you","please","tell","about"]);
export type GroundingDocument = { id: string; title: string; page_number: number; content: string; confidence?: number | null };

export function retrieveDocuments(question: string, conversation: string, documents: GroundingDocument[]) {
  const allTerms = terms(`${question} ${conversation}`);
  const ranked = documents.map(document => ({ document, score: score(document, allTerms) })).sort((a, b) => b.score - a.score);
  const matched = ranked.filter(item => item.score > 0).slice(0, 4).map(item => item.document);
  // Open-ended requests are allowed, but the answer remains bounded by the selected vault evidence.
  return matched.length ? matched : ranked.slice(0, 4).map(item => item.document);
}

export function isGreeting(question: string) { return /^(hi|hello|hey|good (morning|afternoon|evening))[!. ]*$/i.test(question.trim()); }
function terms(text: string) { return new Set(text.toLowerCase().split(/[^a-z0-9]+/).filter(word => word.length > 2 && !STOP_WORDS.has(word))); }
function score(document: GroundingDocument, words: Set<string>) {
  const title = document.title.toLowerCase(), content = document.content.toLowerCase();
  return [...words].reduce((total, word) => total + (title.includes(word) ? 3 : content.includes(word) ? 1 : 0), 0);
}
