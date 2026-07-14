import { Request, Response } from "express";
import { ZodError, z } from "zod";
import { StudyAreasService } from "./study-areas.service";
import {
  CreateStudyAreaSchema,
  UpdateStudyAreaSchema,
  FindOrCreateStudyAreaSchema,
} from "./study-areas.schema";

export class StudyAreasController {
  constructor(private readonly studyAreasService: StudyAreasService) {}

  async getAllStudyAreas(req: Request, res: Response) {
    try {
      const studyAreas = await this.studyAreasService.getAllStudyAreas();
      res.status(200).json(studyAreas);
    } catch (err) {
      res.status(500).json({ message: (err as Error).message });
    }
  }

  async getStudyAreaById(req: Request, res: Response) {
    try {
      const studyArea = await this.studyAreasService.getStudyAreaById(
        req.params.id as string
      );
      res.status(200).json(studyArea);
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async createStudyArea(req: Request, res: Response) {
    try {
      const dto = CreateStudyAreaSchema.parse(req.body);
      const studyArea = await this.studyAreasService.createStudyArea(dto);
      res.status(201).json(studyArea);
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

  async findOrCreateStudyArea(req: Request, res: Response) {
    try {
      const dto = FindOrCreateStudyAreaSchema.parse(req.body);
      const studyArea = await this.studyAreasService.findOrCreateStudyArea(dto);
      res.status(200).json(studyArea);
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

  async updateStudyArea(req: Request, res: Response) {
    try {
      const dto = UpdateStudyAreaSchema.parse(req.body);
      const studyArea = await this.studyAreasService.updateStudyArea(
        req.params.id as string,
        dto
      );
      res.status(200).json(studyArea);
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

  async deleteStudyArea(req: Request, res: Response) {
    try {
      await this.studyAreasService.deleteStudyArea(req.params.id as string);
      res.status(204).send();
    } catch (err) {
      res.status(404).json({ message: (err as Error).message });
    }
  }

  async seedStudyAreas(req: Request, res: Response) {
    try {
      const result = await this.studyAreasService.seedStudyAreas();
      res.status(201).json(result);
    } catch (err) {
      res.status(500).json({ message: (err as Error).message });
    }
  }
}
