import { SummariesService } from "../summaries.service";
import { SummarizerClient } from "../summarizer.client";
import { AppError } from "../../../common/errors/app-error";

describe("SummariesService.summarize", () => {
  function makeService(overrides: Partial<SummarizerClient> = {}) {
    const summarizerClient = {
      summarize: jest.fn(),
      ...overrides,
    } as unknown as SummarizerClient;
    return { service: new SummariesService(summarizerClient), summarizerClient };
  }

  it("rejects empty text with a 400 AppError without calling the client", async () => {
    const { service, summarizerClient } = makeService();

    await expect(service.summarize("   ", "notes")).rejects.toMatchObject({
      message: "Nothing to summarize",
      statusCode: 400,
    });
    expect(summarizerClient.summarize).not.toHaveBeenCalled();
  });

  it("delegates trimmed text to the summarizer client and returns its result", async () => {
    const { service, summarizerClient } = makeService({
      summarize: jest.fn().mockResolvedValue("a concise summary"),
    });

    const result = await service.summarize("  some long dialogue  ", "dialogue");

    expect(result).toBe("a concise summary");
    expect(summarizerClient.summarize).toHaveBeenCalledWith("some long dialogue", "dialogue");
  });

  it("wraps any client failure in a 502 AppError", async () => {
    const { service } = makeService({
      summarize: jest.fn().mockRejectedValue(new Error("network error")),
    });

    await expect(service.summarize("some text", "notes")).rejects.toMatchObject({
      message: "Summarization failed",
      statusCode: 502,
    });
  });

  it("throws an AppError instance on client failure", async () => {
    const { service } = makeService({
      summarize: jest.fn().mockRejectedValue(new Error("boom")),
    });

    await expect(service.summarize("some text", "notes")).rejects.toBeInstanceOf(AppError);
  });
});
