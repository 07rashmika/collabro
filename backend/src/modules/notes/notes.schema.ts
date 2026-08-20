import { z } from "zod";

export const CreateNoteSchema = z.object({
  title: z.string().min(1).max(200),
  content: z.string().min(1),
  tags: z.array(z.string().max(50)).max(10).optional(),
  isPublic: z.boolean().optional().default(false),
  // Generated client-side via POST /notes/summarize before the note is
  // created — carried along so creation doesn't require a second AI call.
  summary: z.string().optional(),
});

export const SummarizeTextSchema = z.object({
  content: z.string().min(1),
});

export const UpdateNoteSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  content: z.string().min(1).optional(),
  tags: z.array(z.string().max(50)).max(10).optional(),
  isPublic: z.boolean().optional(),
});

export const NoteQuerySchema = z.object({
  search: z.string().optional(),
  tag: z.string().optional(),
  // Comma-separated user IDs — restricts /notes/public to notes from a
  // specific set of authors (e.g. the home dashboard's matched/connected
  // partners) instead of every public note.
  authorIds: z
    .string()
    .optional()
    .transform((v) => (v ? v.split(",").filter(Boolean) : undefined)),
  isPublic: z
    .string()
    .optional()
    .transform((v) => (v === "true" ? true : v === "false" ? false : undefined)),
  // Filters to notes that do/don't have an AI-generated summary yet —
  // feeds the home dashboard's "AI Summaries" preview.
  hasSummary: z
    .string()
    .optional()
    .transform((v) => (v === "true" ? true : v === "false" ? false : undefined)),
  page: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 1)),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 10)),
});

export type CreateNoteDto = z.infer<typeof CreateNoteSchema>;
export type UpdateNoteDto = z.infer<typeof UpdateNoteSchema>;
export type NoteQueryDto = z.infer<typeof NoteQuerySchema>;
export type SummarizeTextDto = z.infer<typeof SummarizeTextSchema>;