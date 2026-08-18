import { Request, Response } from "express";
import { ZodError } from "zod";
import { ConnectionsService } from "./connections.service";
import { AppError } from "../../common/errors/app-error";
import { SendConnectionRequestSchema } from "./connections.schema";

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

export class ConnectionsController {
  constructor(private readonly connectionsService: ConnectionsService) {}

  async getMyConnections(req: Request, res: Response) {
    try {
      const userIds = await this.connectionsService.getMyConnectedUserIds(req.user!.sub);
      res.status(200).json({ userIds });
    } catch (err) { handleError(res, err); }
  }

  async sendRequest(req: Request, res: Response) {
    try {
      const dto = SendConnectionRequestSchema.parse(req.body);
      const connection = await this.connectionsService.sendRequest(req.user!.sub, dto);
      res.status(201).json(connection);
    } catch (err) { handleError(res, err); }
  }

  async cancelRequest(req: Request, res: Response) {
    try {
      const dto = SendConnectionRequestSchema.parse(req.body);
      await this.connectionsService.cancelRequest(req.user!.sub, dto.addresseeId);
      res.status(204).send();
    } catch (err) { handleError(res, err); }
  }

  async accept(req: Request, res: Response) {
    try {
      const connection = await this.connectionsService.accept(req.params.id as string, req.user!.sub);
      res.status(200).json(connection);
    } catch (err) { handleError(res, err); }
  }

  async decline(req: Request, res: Response) {
    try {
      const connection = await this.connectionsService.decline(req.params.id as string, req.user!.sub);
      res.status(200).json(connection);
    } catch (err) { handleError(res, err); }
  }
}
