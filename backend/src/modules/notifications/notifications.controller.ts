import { Request, Response } from "express";
import { NotificationsService } from "./notifications.service";

export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  async getMyNotifications(req: Request, res: Response) {
    try {
      const result = await this.notificationsService.getMyNotifications(req.user!.sub);
      res.status(200).json(result);
    } catch (err) {
      res.status(500).json({ message: (err as Error).message });
    }
  }

  async markAllRead(req: Request, res: Response) {
    try {
      await this.notificationsService.markAllRead(req.user!.sub);
      res.status(204).send();
    } catch (err) {
      res.status(500).json({ message: (err as Error).message });
    }
  }
}
