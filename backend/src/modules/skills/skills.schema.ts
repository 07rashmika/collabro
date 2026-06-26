import { z } from "zod";

export const CreateSkillSchema = z.object({
  name: z.string().min(1).max(100),
  category: z.string().min(1).max(100),
});

export const UpdateSkillSchema = CreateSkillSchema.partial();

export type CreateSkillDto = z.infer<typeof CreateSkillSchema>;
export type UpdateSkillDto = z.infer<typeof UpdateSkillSchema>;