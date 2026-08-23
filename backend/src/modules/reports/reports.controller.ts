import { Request, Response } from "express";
import { ZodError } from "zod";
import { ReportsService } from "./reports.service";
import { AppError } from "../../common/errors/app-error";
import { CreateReportSchema } from "./reports.schema";

function handleError(res: Response, err: unknown) {
  if (err instanceof ZodError) {
    res.status(400).json({
      message: "Validation failed",
      errors: err.flatten().fieldErrors,
    });
    return;
  }
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ message: err.message });
    return;
  }
  res.status(500).json({ message: (err as Error).message });
}

export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  async createReport(req: Request, res: Response) {
    try {
      const dto = CreateReportSchema.parse(req.body);
      const report = await this.reportsService.createReport(req.params.id as string, req.user!.sub, dto);
      res.status(201).json(report);
    } catch (err) {
      handleError(res, err);
    }
  }
}
