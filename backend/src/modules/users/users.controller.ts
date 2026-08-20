import { Request, Response } from "express";
import { ZodError, z } from "zod";
import { UsersService } from "./users.service";
import { AppError } from "../../common/errors/app-error";
import { UpdateUserSchema, UserQuerySchema } from "./users.schema";

function handleUserError(res: Response, err: unknown, defaultStatus: number) {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ message: err.message });
    return;
  }
  res.status(defaultStatus).json({ message: (err as Error).message });
}

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
        req.params.id as string,
        req.user!.sub
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

  async uploadAvatar(req: Request, res: Response) {
    try {
      const file = req.file as Express.Multer.File | undefined;
      if (!file) {
        throw new AppError("No image provided", 400);
      }
      const user = await this.usersService.uploadAvatar(req.user!.sub, file);
      res.status(200).json(user);
    } catch (err) {
      handleUserError(res, err, 400);
    }
  }

  async deleteAvatar(req: Request, res: Response) {
    try {
      const user = await this.usersService.deleteAvatar(req.user!.sub);
      res.status(200).json(user);
    } catch (err) {
      handleUserError(res, err, 404);
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