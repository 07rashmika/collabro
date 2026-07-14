import { z } from "zod";

export const CreateSessionSchema = z.object({
  title: z.string().min(1).max(200),
  type: z.enum(["TEXT", "VIDEO"]).default("TEXT"),
  participantIds: z.array(z.string()).max(20).default([]),
  scheduledAt: z
    .string()
    .datetime()
    .optional()
    .refine((val) => !val || new Date(val) > new Date(), {
      message: "Scheduled time must be in the future",
    }),
  password: z.string().min(4).max(100).optional(),
  tagIds: z.array(z.string()).max(10).default([]),
  isPublic: z.boolean().default(false),
});

export const UpdateSessionSchema = z.object({
  title: z.string().min(1).max(200).optional(),
});

export const JoinByCodeSchema = z.object({
  joinCode: z.string().min(1),
  password: z.string().optional(),
});

export const SendMessageSchema = z.object({
  content: z.string().min(1).max(2000),
});

export const SessionQuerySchema = z.object({
  status: z.enum(["ACTIVE", "CLOSED"]).optional(),
  type: z.enum(["TEXT", "VIDEO"]).optional(),
  upcoming: z
    .enum(["true", "false"])
    .optional()
    .transform((v) => v === "true"),
  page: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 1)),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 10)),
});

export const MessageQuerySchema = z.object({
  page: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 1)),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 20)),
});

export const PageQuerySchema = z.object({
  page: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 1)),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 10)),
});

export type CreateSessionDto = z.infer<typeof CreateSessionSchema>;
export type UpdateSessionDto = z.infer<typeof UpdateSessionSchema>;
export type SendMessageDto = z.infer<typeof SendMessageSchema>;
export type SessionQueryDto = z.infer<typeof SessionQuerySchema>;
export type MessageQueryDto = z.infer<typeof MessageQuerySchema>;
export type JoinByCodeDto = z.infer<typeof JoinByCodeSchema>;
export type PageQueryDto = z.infer<typeof PageQuerySchema>;