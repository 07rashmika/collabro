import { z } from "zod";

export const CreateSessionSchema = z.object({
  title: z.string().min(1).max(200),
  type: z.enum(["TEXT", "VIDEO"]).default("TEXT"),
  participantIds: z
    .array(z.string())
    .min(1, "At least one participant is required")
    .max(20),
});

export const UpdateSessionSchema = z.object({
  title: z.string().min(1).max(200).optional(),
});

export const SendMessageSchema = z.object({
  content: z.string().min(1).max(2000),
});

export const SessionQuerySchema = z.object({
  status: z.enum(["ACTIVE", "CLOSED"]).optional(),
  type: z.enum(["TEXT", "VIDEO"]).optional(),
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

export type CreateSessionDto = z.infer<typeof CreateSessionSchema>;
export type UpdateSessionDto = z.infer<typeof UpdateSessionSchema>;
export type SendMessageDto = z.infer<typeof SendMessageSchema>;
export type SessionQueryDto = z.infer<typeof SessionQuerySchema>;
export type MessageQueryDto = z.infer<typeof MessageQuerySchema>;