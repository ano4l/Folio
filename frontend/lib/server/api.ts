import { NextResponse } from "next/server";

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = "ApiError";
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export function jsonError(error: unknown) {
  if (error instanceof ApiError || isHttpError(error)) {
    return NextResponse.json({ message: error.message }, { status: error.status });
  }
  console.error("Folio API failure", error instanceof Error ? error.message : "unknown error");
  return NextResponse.json({ message: "The service is temporarily unavailable" }, { status: 503 });
}

function isHttpError(error: unknown): error is Error & { status: number } {
  return error instanceof Error && "status" in error &&
    typeof (error as { status?: unknown }).status === "number";
}

export function requireMutationHeader(request: Request) {
  if (request.headers.get("x-requested-with") !== "FolioWeb") throw new ApiError(403, "Missing browser request verification");
}

export async function readJson<T>(request: Request): Promise<T> {
  try { return await request.json() as T; }
  catch { throw new ApiError(400, "Invalid JSON request"); }
}
