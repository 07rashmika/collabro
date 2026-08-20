import fs from "fs";

export type TranscriptSegment = { start: number; end: number; text: string };

export class TranscriptionClient {
  constructor(private readonly baseUrl: string) {}

  async transcribe(filePath: string, mimeType: string): Promise<TranscriptSegment[]> {
    const buffer = fs.readFileSync(filePath);
    const form = new FormData();
    form.append("file", new Blob([buffer], { type: mimeType }), filePath.split("/").pop());

    const response = await fetch(`${this.baseUrl}/transcribe`, {
      method: "POST",
      body: form,
    });

    if (!response.ok) {
      throw new Error(`Transcription request failed (${response.status})`);
    }

    const result = (await response.json()) as { segments?: unknown };
    if (!Array.isArray(result.segments)) {
      throw new Error("Transcriber returned an unexpected response shape");
    }

    return result.segments as TranscriptSegment[];
  }
}
