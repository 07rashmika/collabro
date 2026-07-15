import { Request, Response } from "express";
import { ZodError, z } from "zod";
import { UsersService } from "./users.service";
import { UpdateUserSchema, UserQuerySchema } from "./users.schema";

export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  async getMe(req: Request, res: Response) {
    try {
      const user = await this.usersService.getMe(req.user!.sub);
      res.status(200).json(user);
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async getUserById(req: Request, res: Response) {
    try {
      const user = await this.usersService.getUserById(
        req.params.id as string
      );
      res.status(200).json(user);
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async getAllUsers(req: Request, res: Response) {
    try {
      const query = UserQuerySchema.parse(req.query);
      const result = await this.usersService.getAllUsers(req.user!.sub, query);
      res.status(200).json(result);
    } catch (err) {
      res.status(500).json({ message: (err as Error).message });
    }
  }

  async updateMe(req: Request, res: Response) {
    try {
      const dto = UpdateUserSchema.parse(req.body);
      const user = await this.usersService.updateMe(req.user!.sub, dto);
      res.status(200).json(user);
    } catch (err) {
      if (err instanceof ZodError) {
        res.status(400).json({
          message: "Validation failed",
          errors: z.treeifyError(err),
        });
        return;
      }
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async deleteMe(req: Request, res: Response) {
    try {
      await this.usersService.deleteMe(req.user!.sub);
      res.status(204).send();
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async deleteUser(req: Request, res: Response) {
    try {
      await this.usersService.deleteUser(req.params.id as string);
      res.status(204).send();
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }
}