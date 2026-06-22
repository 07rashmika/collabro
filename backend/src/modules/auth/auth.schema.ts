import { z } from "zod";

const STUDENT_EMAIL_DOMAINS = ["university.edu", "student.ac.lk"]; // extend as needed

export const RegisterSchema = z.object({
  name: z.string().min(2).max(100),
  email: z
    .string()
    .email()
    .refine(
      (val) => STUDENT_EMAIL_DOMAINS.some((d) => val.endsWith(`@${d}`)),
      { message: "Only student email addresses are allowed" }
    ),
  password: z.string().min(8).max(64),
});

export const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const RefreshSchema = z.object({
  refreshToken: z.string().min(1),
});

export type RegisterDto = z.infer<typeof RegisterSchema>;
export type LoginDto = z.infer<typeof LoginSchema>;
export type RefreshDto = z.infer<typeof RefreshSchema>;