import { Router } from "express";
import { NotificationsController } from "./notifications.controller";
import { NotificationsService } from "./notifications.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { jwtGuard } from "../../common/guards/jwt.guard";

const router = Router();

const prisma = PrismaService.getInstance();
const notificationsService = new NotificationsService(prisma);
const notificationsController = new NotificationsController(notificationsService);

router.use(jwtGuard);

router.get("/", (req, res) => notificationsController.getMyNotifications(req, res));
router.patch("/read-all", (req, res) => notificationsController.markAllRead(req, res));

export default router;
