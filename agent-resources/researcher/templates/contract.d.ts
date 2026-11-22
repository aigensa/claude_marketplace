// docs/contracts/<name>-vN.d.ts. In-language API contract for a TypeScript library. Checked with tsc --strict.
export type ErrorCategory = "provider" | "invalid_output" | "limit";

export interface HarnessResult {
  status: "ok" | "error";
  output: unknown | null;
}

export interface Session {
  run(prompt: string, opts?: { outputSchema?: Record<string, unknown>; maxRepairs?: number }): Promise<HarnessResult>;
}
