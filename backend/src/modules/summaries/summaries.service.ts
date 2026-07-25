import { AppError } from "../../common/errors/app-error";
import { SummarizerClient, SummaryTask } from "./summarizer.client";

export class SummariesService {
  constructor(private readonly summarizerClient: SummarizerClient) {}

  async summarize(text: string, task: SummaryTask): Promise<string> {
    const trimmed = text.trim();
    if (!trimmed) {
      throw new AppError("Nothing to summarize", 400);
    }

    try {
      return await this.summarizerClient.summarize(trimmed, task);
    } catch {
      throw new AppError("Summarization failed", 502);
    }
  }
}
