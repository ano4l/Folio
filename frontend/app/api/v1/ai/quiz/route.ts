import { NextRequest } from "next/server";
import {
  ApiError,
  jsonError,
  readJson,
  requireMutationHeader,
} from "@/lib/server/api";
import { currentUser } from "@/lib/server/auth";
import { expandDocumentPages, GroundingDocument } from "@/lib/server/grounding";
import { supabaseAdmin } from "@/lib/server/supabase";
import { aiConfigured, generateOpenRouterText } from "@/lib/server/openrouter";
import { generateStudyQuiz } from "@/lib/server/study-quiz";
import { quizGenerator } from "@/lib/server/quiz-provider";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const maxDuration = 60;

type QuizBody = {
  documentId?: unknown;
  count?: unknown;
  difficulty?: unknown;
  focus?: unknown;
};

export async function POST(request: NextRequest) {
  try {
    requireMutationHeader(request);
    const user = await currentUser(request);
    const body = await readJson<QuizBody>(request);
    if (!body || typeof body !== "object" || Array.isArray(body))
      throw new ApiError(400, "Invalid quiz request");
    if (
      typeof body.documentId !== "string" ||
      !body.documentId.trim() ||
      body.documentId.length > 80
    ) {
      throw new ApiError(400, "Choose a document to study");
    }
    const documentId = body.documentId.trim();
    if (
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        documentId,
      )
    ) {
      throw new ApiError(400, "Choose a valid source document");
    }
    const count = body.count ?? 5,
      difficulty = body.difficulty ?? "standard",
      focus = body.focus ?? "";
    if (
      ![3, 5, 8].includes(count as number) ||
      !["foundation", "standard", "challenge"].includes(difficulty as string) ||
      typeof focus !== "string" ||
      focus.length > 300
    )
      throw new ApiError(
        400,
        "Choose a valid quiz length, difficulty and topic",
      );

    const supabase = supabaseAdmin();
    const { data: row, error } = await supabase
      .from("vault_documents")
      .select("id,title,content,status")
      .eq("id", documentId)
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .maybeSingle();
    if (error)
      throw new Error(`Unable to retrieve study source: ${error.code}`);
    if (!row || row.status !== "READY" || typeof row.content !== "string") {
      throw new ApiError(404, "This document is not ready to make a quiz");
    }
    const pages = expandDocumentPages([
      {
        id: row.id,
        title: row.title,
        page_number: null,
        content: row.content,
      } as GroundingDocument,
    ]).filter((page) => page.content.trim());
    const stride = Math.max(1, Math.ceil(pages.length / 8));
    const evidence = pages
      .filter((_, index) => index % stride === 0)
      .slice(0, 8)
      .map((page, index) => ({
        number: index + 1,
        page: page.page_number,
        text: page.content.slice(0, 2600),
      }));
    if (
      !evidence.length ||
      evidence.every((page) => page.text.trim().length < 80)
    ) {
      throw new ApiError(
        422,
        "There is not enough readable text in this document to make a quiz yet",
      );
    }
    if (!aiConfigured())
      throw new ApiError(503, "The study assistant is not configured yet");

    let quiz;
    try {
      quiz = await generateStudyQuiz(
        evidence,
        {
          documentId: row.id,
          title: row.title,
          count: count as 3 | 5 | 8,
          difficulty: difficulty as string,
          focus,
        },
        quizGenerator(
          generateOpenRouterText,
          process.env.OPENROUTER_QUIZ_MODEL?.trim() ||
            "apodex/apodex-1.1-mini:free",
          process.env.OPENROUTER_QUIZ_FALLBACK_MODEL?.trim() ||
            "cohere/north-mini-code:free",
        ),
        AbortSignal.any([request.signal, AbortSignal.timeout(48_000)]),
      );
    } catch (error) {
      console.warn(
        "Quiz generation failed",
        error instanceof Error ? error.message : "Unknown provider error",
      );
      throw new ApiError(
        503,
        "Folio could not finish a source-based quiz. Please retry; your document is unchanged.",
      );
    }
    const { error: auditError } = await supabase.from("ai_queries").insert({
      user_id: user.id,
      grounded: true,
      abstained: false,
      model: quiz.model,
      source_count: 1,
    });
    if (auditError)
      console.warn("Quiz activity could not be recorded", auditError.code);
    return Response.json(
      {
        ...quiz,
        difficulty,
        requestedCount: count,
        coverage:
          "Sampled readable passages; questions may not cover every page.",
      },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (error) {
    return jsonError(error);
  }
}
