import { z } from "zod";

export const CreateProfileSchema = z.object({
  bio: z.string().max(500).optional(),
  learningGoal: z.string().max(200).optional(),
  teachGoal: z.string().max(200).optional(),
  skills: z
    .array(
      z.object({
        skillId: z.string().min(1),
        level: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]),
      })
    )
    .optional(),
});

export const UpdateProfileSchema = CreateProfileSchema.partial();

export const AddSkillSchema = z.object({
  skillId: z.string().min(1),
  level: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]),
});

export const RemoveSkillSchema = z.object({
  skillId: z.string().min(1),
});

export type CreateProfileDto = z.infer<typeof CreateProfileSchema>;
export type UpdateProfileDto = z.infer<typeof UpdateProfileSchema>;
export type AddSkillDto = z.infer<typeof AddSkillSchema>;
export type RemoveSkillDto = z.infer<typeof RemoveSkillSchema>;