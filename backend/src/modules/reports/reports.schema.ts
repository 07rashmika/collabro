import { z } from "zod";

export const ReportReasonValues = [
  "SPAM_OR_ADVERTISING",
  "HARASSMENT_OR_BULLYING",
  "HATE_SPEECH_OR_DISCRIMINATION",
  "INAPPROPRIATE_CONTENT",
  "ACADEMIC_DISHONESTY",
  "IMPERSONATION_OR_FAKE_PROFILE",
  "SCAM_OR_PHISHING",
  "OTHER",
] as const;

export const CreateReportSchema = z
  .object({
    targetType: z.enum(["SESSION", "USER"]),
    reportedUserId: z.string().min(1).optional(),
    reason: z.enum(ReportReasonValues),
    details: z.string().max(1000).optional(),
  })
  .refine((data) => data.targetType !== "USER" || !!data.reportedUserId, {
    message: "reportedUserId is required when targetType is USER",
    path: ["reportedUserId"],
  });

export type CreateReportDto = z.infer<typeof CreateReportSchema>;
