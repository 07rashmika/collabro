import { z } from "zod";

export const UpdateUserSchema = z.object({
  name: z.string().min(2).max(100).optional(),
  notifyMessages: z.boolean().optional(),
  notifyConnections: z.boolean().optional(),
  notifyVideoSessions: z.boolean().optional(),
});

export const RegisterDeviceTokenSchema = z.object({
  token: z.string().min(1),
  platform: z.string().min(1).default("android"),
});

export const UserQuerySchema = z.object({
  search: z.string().optional(),
  page: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 1)),
  limit: z
    .string()
    .optional()
    .transform((v) => (v ? parseInt(v) : 10)),
});

export type UpdateUserDto = z.infer<typeof UpdateUserSchema>;
export type UserQueryDto = z.infer<typeof UserQuerySchema>;
export type RegisterDeviceTokenDto = z.infer<typeof RegisterDeviceTokenSchema>;