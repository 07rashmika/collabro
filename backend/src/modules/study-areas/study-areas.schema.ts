import { z } from "zod";

export const CreateStudyAreaSchema = z.object({
  name: z.string().min(1).max(100),
});

export const UpdateStudyAreaSchema = CreateStudyAreaSchema.partial();

export const FindOrCreateStudyAreaSchema = z.object({
  name: z.string().min(1).max(100),
});

export type CreateStudyAreaDto = z.infer<typeof CreateStudyAreaSchema>;
export type UpdateStudyAreaDto = z.infer<typeof UpdateStudyAreaSchema>;
export type FindOrCreateStudyAreaDto = z.infer<typeof FindOrCreateStudyAreaSchema>;
