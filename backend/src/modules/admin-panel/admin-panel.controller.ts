import { Request, Response } from "express";
import { ZodError } from "zod";
import { AppError } from "../../common/errors/app-error";
import { AdminPanelService } from "./admin-panel.service";
import {
  AdminLoginSchema,
  SuspendUserSchema,
  UpdateReportStatusSchema,
  AdminUserQuerySchema,
  AdminSessionQuerySchema,
  AdminReportQuerySchema,
} from "./admin-panel.schema";

function handleError(res: Response, err: unknown) {
  if (err instanceof ZodError) {
    res.status(400).json({ message: "Validation failed", errors: err.flatten().fieldErrors });
    return;
  }
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ message: err.message });
    return;
  }
  res.status(500).json({ message: (err as Error).message });
}

export class AdminPanelController {
  constructor(private readonly adminPanelService: AdminPanelService) {}

  async login(req: Request, res: Response) {
    try {
      const dto = AdminLoginSchema.parse(req.body);
      const result = this.adminPanelService.login(dto);
      res.status(200).json(result);
    } catch (err) {
      handleError(res, err);
    }
  }

  async getDashboard(_req: Request, res: Response) {
    try {
      const result = await this.adminPanelService.getDashboard();
      res.status(200).json(result);
    } catch (err) {
      handleError(res, err);
    }
  }

  async listUsers(req: Request, res: Response) {
    try {
      const query = AdminUserQuerySchema.parse(req.query);
      const result = await this.adminPanelService.listUsers(query);
      res.status(200).json(result);
    } catch (err) {
      handleError(res, err);
    }
  }

  async suspendUser(req: Request, res: Response) {
    try {
      const dto = SuspendUserSchema.parse(req.body);
      const result = await this.adminPanelService.suspendUser(req.params.id as string, dto);
      res.status(200).json(result);
    } catch (err) {
      handleError(res, err);
    }
  }

  async unsuspendUser(req: Request, res: Response) {
    try {
      const result = await this.adminPanelService.unsuspendUser(req.params.id as string);
      res.status(200).json(result);
    } catch (err) {
      handleError(res, err);
    }
  }

  async listSessions(req: Request, res: Response) {
    try {
      const query = AdminSessionQuerySchema.parse(req.query);
      const result = await this.adminPanelService.listSessions(query);
      res.status(200).json(result);
    } catch (err) {
      handleError(res, err);
    }
  }

  async listReports(req: Request, res: Response) {
    try {
      const query = AdminReportQuerySchema.parse(req.query);
      const result = await this.adminPanelService.listReports(query);
      res.status(200).json(result);
    } catch (err) {
      handleError(res, err);
    }
  }

  async updateReportStatus(req: Request, res: Response) {
    try {
      const dto = UpdateReportStatusSchema.parse(req.body);
      const result = await this.adminPanelService.updateReportStatus(
        req.params.id as string,
        dto.status
      );
      res.status(200).json(result);
    } catch (err) {
      handleError(res, err);
    }
  }
}
