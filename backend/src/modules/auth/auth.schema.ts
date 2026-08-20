import { z } from "zod";

export const RegisterSchema = z.object({
  name: z.string().min(2).max(100),
  email: z.string().email(),
  password: z.string().min(8).max(64),
});

export const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const RefreshSchema = z.object({
  refreshToken: z.string().min(1),
});

export const GoogleAuthSchema = z.object({
  idToken: z.string().min(1),
});

export const ForgotPasswordSchema = z.object({
  email: z.string().email(),
});

export const VerifyResetCodeSchema = z.object({
  email: z.string().email(),
  code: z.string().length(6).regex(/^\d{6}$/, "Code must be 6 digits"),
});

export const ResetPasswordSchema = z.object({
  resetToken: z.string().min(1),
  newPassword: z.string().min(8).max(64),
});

export type RegisterDto         = z.infer<typeof RegisterSchema>;
export type LoginDto            = z.infer<typeof LoginSchema>;
export type RefreshDto          = z.infer<typeof RefreshSchema>;
export type GoogleAuthDto       = z.infer<typeof GoogleAuthSchema>;
export type ForgotPasswordDto   = z.infer<typeof ForgotPasswordSchema>;
export type VerifyResetCodeDto  = z.infer<typeof VerifyResetCodeSchema>;
export type ResetPasswordDto    = z.infer<typeof ResetPasswordSchema>;