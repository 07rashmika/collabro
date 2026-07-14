import { Request, Response } from "express";
import { ZodError, z } from "zod";
import { SkillsService } from "./skills.service";
import { CreateSkillSchema, UpdateSkillSchema, FindOrCreateSkillSchema } from "./skills.schema";

export class SkillsController {
  constructor(private readonly skillsService: SkillsService) {}

  async getAllSkills(req: Request, res: Response) {
    try {
      const { category } = req.query;

      const skills = category
        ? await this.skillsService.getSkillsByCategory(category as string)
        : await this.skillsService.getAllSkills();

      res.status(200).json(skills);
    } catch (err) {
      res.status(500).json({ message: (err as Error).message });
    }
  }

  async getSkillById(req: Request, res: Response) {
    try {
      const skill = await this.skillsService.getSkillById(
        req.params.id as string
      );
      res.status(200).json(skill);
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async searchSkills(req: Request, res: Response) {
    try {
      const q = (req.query.q as string | undefined)?.trim();
      if (!q) {
        res.status(400).json({ message: "Query param 'q' is required" });
        return;
      }
      const count = req.query.count ? Number(req.query.count) : undefined;
      const skills = await this.skillsService.searchExternalSkills(q, count);
      res.status(200).json(skills);
    } catch (err) {
      res.status(502).json({ message: (err as Error).message });
    }
  }

  async getCategories(req: Request, res: Response) {
    try {
      const categories = await this.skillsService.getCategories();
      res.status(200).json(categories);
    } catch (err) {
      res.status(500).json({ message: (err as Error).message });
    }
  }

  async createSkill(req: Request, res: Response) {
    try {
      const dto = CreateSkillSchema.parse(req.body);
      const skill = await this.skillsService.createSkill(dto);
      res.status(201).json(skill);
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

  async findOrCreateSkill(req: Request, res: Response) {
    try {
      const dto = FindOrCreateSkillSchema.parse(req.body);
      const skill = await this.skillsService.findOrCreateSkill(dto);
      res.status(200).json(skill);
    } catch (err) {
      if (err instanceof ZodError) {
        res
          .status(400)
          .json({ message: "Validation failed", errors: z.treeifyError(err) });
        return;
      }
      res.status(500).json({ message: (err as Error).message });
    }
  }

  async updateSkill(req: Request, res: Response) {
    try {
      const dto = UpdateSkillSchema.parse(req.body);
      const skill = await this.skillsService.updateSkill(
        req.params.id as string,
        dto
      );
      res.status(200).json(skill);
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

  async deleteSkill(req: Request, res: Response) {
    try {
      await this.skillsService.deleteSkill(req.params.id as string);
      res.status(204).send();
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async seedSkills(req: Request, res: Response) {
    try {
      const result = await this.skillsService.seedSkills();
      res.status(201).json(result);
    } catch (err) {
      res.status(500).json({ message: (err as Error).message });
    }
  }
}