const STOP_WORDS = new Set(["the","a","an","and","or","is","are","was","were","to","of","in","on","for","my","me","i","it","that","this","what","when","how","can","you","please","tell","about"]);
const DOMAIN_WORDS = new Set(["document","documents","vault","funding","fund","bursary","fees","fee","tuition","deadline","registration","award","balance","bank","disbursement","appeal","student","university","condition","renewal","payment","amount","proof","account","letter","statement","agreement","nsfas"]);
export type GroundingDocument = { id: string; title: string; page_number: number; content: string };

export function retrieveDocuments(question: string, conversation: string, documents: GroundingDocument[]) {
  const currentTerms = terms(question), allTerms = terms(`${question} ${conversation}`);
  const ranked = documents.map(document => ({ document, score: score(document, allTerms) })).sort((a, b) => b.score - a.score);
  const directScore = Math.max(0, ...documents.map(document => score(document, currentTerms)));
  const domainRelevant = [...currentTerms].some(term => DOMAIN_WORDS.has(term));
  const contextualFollowUp = Boolean(conversation) && /^(and |but |what about|how about|why|explain|summari[sz]e|compare|does that|is that|can i|should i|when is it|what is it)/i.test(question.trim());
  if (!domainRelevant && directScore === 0 && !contextualFollowUp) return [];
  const matched = ranked.filter(item => item.score > 0).slice(0, 4).map(item => item.document);
  return matched.length ? matched : ranked.slice(0, 4).map(item => item.document);
}

export function isGreeting(question: string) { return /^(hi|hello|hey|good (morning|afternoon|evening))[!. ]*$/i.test(question.trim()); }
function terms(text: string) { return new Set(text.toLowerCase().split(/[^a-z0-9]+/).filter(word => word.length > 2 && !STOP_WORDS.has(word))); }
function score(document: GroundingDocument, words: Set<string>) {
  const title = document.title.toLowerCase(), content = document.content.toLowerCase();
  return [...words].reduce((total, word) => total + (title.includes(word) ? 3 : content.includes(word) ? 1 : 0), 0);
}
