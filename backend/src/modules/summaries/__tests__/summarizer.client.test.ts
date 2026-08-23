import { SummarizerClient } from "../summarizer.client";

describe("SummarizerClient.summarize", () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
  });

  it("POSTs the trimmed text and task to <baseUrl>/summarize", async () => {
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ summary: "a summary" }),
    });
    global.fetch = fetchMock as unknown as typeof fetch;
    const client = new SummarizerClient("http://ml-service:8000");

    await client.summarize("some dialogue text", "dialogue");

    expect(fetchMock).toHaveBeenCalledWith(
      "http://ml-service:8000/summarize",
      expect.objectContaining({
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: "some dialogue text", task: "dialogue" }),
      })
    );
  });

  it("returns the summary string on a successful response", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ summary: "a concise summary" }),
    }) as unknown as typeof fetch;
    const client = new SummarizerClient("http://ml-service:8000");

    const result = await client.summarize("text", "notes");

    expect(result).toBe("a concise summary");
  });

  it("throws when the response is not OK", async () => {
    global.fetch = jest.fn().mockResolvedValue({ ok: false, status: 503 }) as unknown as typeof fetch;
    const client = new SummarizerClient("http://ml-service:8000");

    await expect(client.summarize("text", "notes")).rejects.toThrow("Summarizer request failed (503)");
  });

  it("throws when the response body doesn't contain a string summary", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ summary: 42 }),
    }) as unknown as typeof fetch;
    const client = new SummarizerClient("http://ml-service:8000");

    await expect(client.summarize("text", "notes")).rejects.toThrow(
      "Summarizer returned an unexpected response shape"
    );
  });

  it("throws when the response body has no summary field at all", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({}),
    }) as unknown as typeof fetch;
    const client = new SummarizerClient("http://ml-service:8000");

    await expect(client.summarize("text", "notes")).rejects.toThrow(
      "Summarizer returned an unexpected response shape"
    );
  });
});
