import { Request, Response } from "express";
import { AuthService } from "./auth.service";
import {
  RegisterSchema,
  LoginSchema,
  RefreshSchema,
  GoogleAuthSchema,
  ForgotPasswordSchema,
  VerifyResetCodeSchema,
  ResetPasswordSchema,
} from "./auth.schema";
import { AppError } from "../../common/errors/app-error";
import { ZodError, z } from "zod";

function handleAuthError(res: Response, err: unknown, defaultStatus: number) {
  if (err instanceof ZodError) {
    res.status(400).json({ message: "Validation failed", errors: z.treeifyError(err) });
    return;
  }
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ message: err.message });
    return;
  }
  res.status(defaultStatus).json({ message: (err as Error).message });
}

export class AuthController {
  constructor(private readonly authService: AuthService) {}

  async register(req: Request, res: Response) {
    try {
      const dto = RegisterSchema.parse(req.body);
      const result = await this.authService.register(dto);
      res.status(201).json(result);
    } catch (err) {
      if (err instanceof ZodError) {
        res.status(400).json({ message: "Validation failed", errors: z.treeifyError(err) });
        return;
      }
      res.status(409).json({ message: (err as Error).message });
    }
  }

  async login(req: Request, res: Response) {
    try {
      const dto = LoginSchema.parse(req.body);
      const result = await this.authService.login(dto);
      res.status(200).json(result);
    } catch (err) {
      handleAuthError(res, err, 401);
    }
  }

  async googleLogin(req: Request, res: Response) {
    try {
      const dto = GoogleAuthSchema.parse(req.body);
      const result = await this.authService.loginWithGoogle(dto.idToken);
      res.status(200).json(result);
    } catch (err) {
      if (err instanceof ZodError) {
        res.status(400).json({ message: "Validation failed", errors: z.treeifyError(err) });
        return;
      }
      res.status(401).json({ message: (err as Error).message });
    }
  }

  async refresh(req: Request, res: Response) {
    try {
      const { refreshToken } = RefreshSchema.parse(req.body);
      const result = await this.authService.refresh(refreshToken);
      res.status(200).json(result);
    } catch (err) {
      if (err instanceof ZodError) {
        res.status(400).json({ message: "Validation failed", errors: z.treeifyError(err) });
        return;
      }
      res.status(401).json({ message: (err as Error).message });
    }
  }

  async logout(req: Request, res: Response) {
    try {
      await this.authService.logout(req.user!.sub);
      res.status(204).send();
    } catch (err) {
      res.status(500).json({ message: "Logout failed" });
    }
  }

  async forgotPassword(req: Request, res: Response) {
    try {
      const dto = ForgotPasswordSchema.parse(req.body);
      const result = await this.authService.forgotPassword(dto.email);
      res.status(200).json(result);
    } catch (err) {
      handleAuthError(res, err, 500);
    }
  }

  async verifyResetCode(req: Request, res: Response) {
    try {
      const dto = VerifyResetCodeSchema.parse(req.body);
      const result = await this.authService.verifyResetCode(dto.email, dto.code);
      res.status(200).json(result);
    } catch (err) {
      handleAuthError(res, err, 400);
    }
  }

  async resetPassword(req: Request, res: Response) {
    try {
      const dto = ResetPasswordSchema.parse(req.body);
      await this.authService.resetPassword(dto.resetToken, dto.newPassword);
      res.status(200).json({ message: "Password reset. Please sign in with your new password." });
    } catch (err) {
      handleAuthError(res, err, 400);
    }
  }
}