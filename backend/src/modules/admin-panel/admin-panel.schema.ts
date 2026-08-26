import { z } from "zod";

export const AdminLoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const SuspendUserSchema = z.object({
  reason: z.string().max(500).optional(),
  reportId: z.string().min(1).optional(),
});

export const UpdateReportStatusSchema = z.object({
  status: z.enum(["REVIEWED", "DISMISSED"]),
});

export const AdminUserQuerySchema = z.object({
  search: z.string().optional(),
  status: z.enum(["ACTIVE", "SUSPENDED"]).optional(),
  page: z.string().optional().transform((v) => (v ? parseInt(v) : 1)),
  limit: z.string().optional().transform((v) => (v ? parseInt(v) : 20)),
});

export const AdminSessionQuerySchema = z.object({
  category: z.enum(["ONGOING", "UPCOMING", "ENDED"]),
  search: z.string().optional(),
  page: z.string().optional().transform((v) => (v ? parseInt(v) : 1)),
  limit: z.string().optional().transform((v) => (v ? parseInt(v) : 20)),
});

export const AdminReportQuerySchema = z.object({
  targetType: z.enum(["SESSION", "USER"]).optional(),
  status: z.enum(["PENDING", "REVIEWED", "DISMISSED"]).optional(),
  page: z.string().optional().transform((v) => (v ? parseInt(v) : 1)),
  limit: z.string().optional().transform((v) => (v ? parseInt(v) : 20)),
});

export type AdminLoginDto = z.infer<typeof AdminLoginSchema>;
export type SuspendUserDto = z.infer<typeof SuspendUserSchema>;
export type UpdateReportStatusDto = z.infer<typeof UpdateReportStatusSchema>;
export type AdminUserQueryDto = z.infer<typeof AdminUserQuerySchema>;
export type AdminSessionQueryDto = z.infer<typeof AdminSessionQuerySchema>;
export type AdminReportQueryDto = z.infer<typeof AdminReportQuerySchema>;
