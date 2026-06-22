import { Request, Response } from "express";
import { AuthService } from "./auth.service";
import { RegisterSchema, LoginSchema, RefreshSchema } from "./auth.schema";
import { ZodError, z } from "zod";

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
}