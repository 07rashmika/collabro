import { z } from "zod";

export const CreateProfileSchema = z.object({
  bio: z.string().max(500).optional(),
  learningGoal: z.string().max(200).optional(),
  teachGoal: z.string().max(200).optional(),
  interests: z.array(z.string().min(1).max(50)).max(30).optional(),
  skills: z
    .array(
      z.object({
        skillId: z.string().min(1),
        level: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]),
      })
    )
    .optional(),
  studyAreaIds: z.array(z.string().min(1)).optional(),
});

export const UpdateProfileSchema = CreateProfileSchema.partial();

export const AddSkillSchema = z.object({
  skillId: z.string().min(1),
  level: z.enum(["BEGINNER", "INTERMEDIATE", "ADVANCED"]),
});

export const RemoveSkillSchema = z.object({
  skillId: z.string().min(1),
});

export const AddStudyAreaSchema = z.object({
  studyAreaId: z.string().min(1),
});

export const RemoveStudyAreaSchema = z.object({
  studyAreaId: z.string().min(1),
});

export type CreateProfileDto = z.infer<typeof CreateProfileSchema>;
export type UpdateProfileDto = z.infer<typeof UpdateProfileSchema>;
export type AddSkillDto = z.infer<typeof AddSkillSchema>;
export type RemoveSkillDto = z.infer<typeof RemoveSkillSchema>;
export type AddStudyAreaDto = z.infer<typeof AddStudyAreaSchema>;
export type RemoveStudyAreaDto = z.infer<typeof RemoveStudyAreaSchema>;