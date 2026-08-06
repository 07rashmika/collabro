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

export type RegisterDto   = z.infer<typeof RegisterSchema>;
export type LoginDto      = z.infer<typeof LoginSchema>;
export type RefreshDto    = z.infer<typeof RefreshSchema>;
export type GoogleAuthDto = z.infer<typeof GoogleAuthSchema>;