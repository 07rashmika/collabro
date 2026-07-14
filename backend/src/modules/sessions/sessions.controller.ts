import { Request, Response } from "express";
import { ZodError } from "zod";
import { SessionsService } from "./sessions.service";
import { AppError }        from "../../common/errors/app-error";
import {
  CreateSessionSchema,
  UpdateSessionSchema,
  SendMessageSchema,
  SessionQuerySchema,
  MessageQuerySchema,
  JoinByCodeSchema,
  PageQuerySchema,
} from "./sessions.schema";

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

export class SessionsController {
  constructor(private readonly sessionsService: SessionsService) {}

  async getMySessions(req: Request, res: Response) {
    try {
      const query  = SessionQuerySchema.parse(req.query);
      const result = await this.sessionsService.getMySessions(req.user!.sub, query);
      res.status(200).json(result);
    } catch (err) { handleError(res, err); }
  }

  async getSessionById(req: Request, res: Response) {
    try {
      const session = await this.sessionsService.getSessionById(req.params.id as string, req.user!.sub);
      res.status(200).json(session);
    } catch (err) { handleError(res, err); }
  }

  async createSession(req: Request, res: Response) {
    try {
      const dto     = CreateSessionSchema.parse(req.body);
      const session = await this.sessionsService.createSession(req.user!.sub, dto);
      res.status(201).json(session);
    } catch (err) { handleError(res, err); }
  }

  async joinByCode(req: Request, res: Response) {
    try {
      const dto     = JoinByCodeSchema.parse(req.body);
      const session = await this.sessionsService.joinSessionByCode(req.user!.sub, dto);
      res.status(200).json(session);
    } catch (err) { handleError(res, err); }
  }

  async discoverSessions(req: Request, res: Response) {
    try {
      const query  = PageQuerySchema.parse(req.query);
      const result = await this.sessionsService.discoverPublicSessions(req.user!.sub, query);
      res.status(200).json(result);
    } catch (err) { handleError(res, err); }
  }

  async getSavedSessions(req: Request, res: Response) {
    try {
      const query  = PageQuerySchema.parse(req.query);
      const result = await this.sessionsService.getSavedSessions(req.user!.sub, query);
      res.status(200).json(result);
    } catch (err) { handleError(res, err); }
  }

  async saveSession(req: Request, res: Response) {
    try {
      await this.sessionsService.saveSession(req.user!.sub, req.params.id as string);
      res.status(204).send();
    } catch (err) { handleError(res, err); }
  }

  async unsaveSession(req: Request, res: Response) {
    try {
      await this.sessionsService.unsaveSession(req.user!.sub, req.params.id as string);
      res.status(204).send();
    } catch (err) { handleError(res, err); }
  }

  async getSessionPassword(req: Request, res: Response) {
    try {
      const result = await this.sessionsService.getSessionPassword(req.params.id as string, req.user!.sub);
      res.status(200).json(result);
    } catch (err) { handleError(res, err); }
  }

  async updateSession(req: Request, res: Response) {
    try {
      const dto     = UpdateSessionSchema.parse(req.body);
      const session = await this.sessionsService.updateSession(req.params.id as string, req.user!.sub, dto);
      res.status(200).json(session);
    } catch (err) { handleError(res, err); }
  }

  async closeSession(req: Request, res: Response) {
    try {
      const session = await this.sessionsService.closeSession(req.params.id as string, req.user!.sub);
      res.status(200).json(session);
    } catch (err) { handleError(res, err); }
  }

  async deleteSession(req: Request, res: Response) {
    try {
      await this.sessionsService.deleteSession(req.params.id as string, req.user!.sub);
      res.status(204).send();
    } catch (err) { handleError(res, err); }
  }

  async addParticipant(req: Request, res: Response) {
    try {
      const result = await this.sessionsService.addParticipant(
        req.params.id as string, req.user!.sub, req.params.userId as string
      );
      res.status(200).json(result);
    } catch (err) { handleError(res, err); }
  }

  async removeParticipant(req: Request, res: Response) {
    try {
      await this.sessionsService.removeParticipant(
        req.params.id as string, req.user!.sub, req.params.userId as string
      );
      res.status(204).send();
    } catch (err) { handleError(res, err); }
  }

  async getMessages(req: Request, res: Response) {
    try {
      const query  = MessageQuerySchema.parse(req.query);
      const result = await this.sessionsService.getMessages(
        req.params.id as string, req.user!.sub, query
      );
      res.status(200).json(result);
    } catch (err) { handleError(res, err); }
  }

  async sendMessage(req: Request, res: Response) {
    try {
      const dto     = SendMessageSchema.parse(req.body);
      const message = await this.sessionsService.sendMessage(
        req.params.id as string, req.user!.sub, dto
      );
      res.status(201).json(message);
    } catch (err) { handleError(res, err); }
  }

  async deleteMessage(req: Request, res: Response) {
    try {
      await this.sessionsService.deleteMessage(req.params.messageId as string, req.user!.sub);
      res.status(204).send();
    } catch (err) { handleError(res, err); }
  }

  async getZegoToken(req: Request, res: Response) {
    try {
      const result = await this.sessionsService.getZegoToken(req.params.id as string, req.user!.sub);
      res.status(200).json(result);
    } catch (err) { handleError(res, err); }
  }
}