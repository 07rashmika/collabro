import { z } from "zod";

export const MatchingQuerySchema = z.object({
  category: z.string().optional(),
  minScore: z
    .string()
    .optional()
    .transform((v) => (v ? parseFloat(v) : 0)),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 10)),
});

export type MatchingQueryDto = z.infer<typeof MatchingQuerySchema>;