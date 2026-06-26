import { Request, Response } from "express";
import { ZodError, z } from "zod";
import { ProfilesService } from "./profiles.service";
import {
  CreateProfileSchema,
  UpdateProfileSchema,
  AddSkillSchema,
  RemoveSkillSchema,
} from "./profiles.schema";

export class ProfilesController {
  constructor(private readonly profilesService: ProfilesService) {}

  async getMyProfile(req: Request, res: Response) {
    try {
      const profile = await this.profilesService.getMyProfile(req.user!.sub);
      res.status(200).json(profile);
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async getProfileByUserId(req: Request, res: Response) {
    try {
      const profile = await this.profilesService.getProfileByUserId(
        req.params.userId as string
      );
      res.status(200).json(profile);
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async createProfile(req: Request, res: Response) {
    try {
      const dto = CreateProfileSchema.parse(req.body);
      const profile = await this.profilesService.createProfile(
        req.user!.sub,
        dto
      );
      res.status(201).json(profile);
    } catch (err) {
      if (err instanceof ZodError) {
        res
          .status(400)
          .json({ message: "Validation failed", errors: z.treeifyError(err) });
        return;
      }
      res.status(409).json({ message: (err as Error).message });
    }
  }

  async updateProfile(req: Request, res: Response) {
    try {
      const dto = UpdateProfileSchema.parse(req.body);
      const profile = await this.profilesService.updateProfile(
        req.user!.sub,
        dto
      );
      res.status(200).json(profile);
    } catch (err) {
      if (err instanceof ZodError) {
        res
          .status(400)
          .json({ message: "Validation failed", errors: z.treeifyError(err) });
        return;
      }
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async addSkill(req: Request, res: Response) {
    try {
      const dto = AddSkillSchema.parse(req.body);
      const result = await this.profilesService.addSkill(req.user!.sub, dto);
      res.status(200).json(result);
    } catch (err) {
      if (err instanceof ZodError) {
        res
          .status(400)
          .json({ message: "Validation failed", errors: z.treeifyError(err) });
        return;
      }
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async removeSkill(req: Request, res: Response) {
    try {
      const dto = RemoveSkillSchema.parse(req.body);
      await this.profilesService.removeSkill(req.user!.sub, dto);
      res.status(204).send();
    } catch (err) {
      if (err instanceof ZodError) {
        res
          .status(400)
          .json({ message: "Validation failed", errors: z.treeifyError(err) });
        return;
      }
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async deleteProfile(req: Request, res: Response) {
    try {
      await this.profilesService.deleteProfile(req.user!.sub);
      res.status(204).send();
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }
}