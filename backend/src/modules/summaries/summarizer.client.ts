export type SummaryTask = "dialogue" | "notes";

export class SummarizerClient {
  constructor(private readonly baseUrl: string) {}

  async summarize(text: string, task: SummaryTask): Promise<string> {
    const response = await fetch(`${this.baseUrl}/summarize`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text, task }),
    });

    if (!response.ok) {
      throw new Error(`Summarizer request failed (${response.status})`);
    }

    const result = (await response.json()) as { summary?: unknown };
    if (typeof result.summary !== "string") {
      throw new Error("Summarizer returned an unexpected response shape");
    }

    return result.summary;
  }
}
