import { Router } from "express";
import { AdminPanelController } from "./admin-panel.controller";
import { AdminPanelService } from "./admin-panel.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { adminPanelGuard } from "../../common/guards/admin-panel.guard";

const router = Router();

const prisma = PrismaService.getInstance();
const adminPanelService = new AdminPanelService(prisma);
const adminPanelController = new AdminPanelController(adminPanelService);

// Public
router.post("/login", (req, res) => adminPanelController.login(req, res));

// Everything below requires a valid admin panel session token
router.use(adminPanelGuard);

router.get("/dashboard", (req, res) => adminPanelController.getDashboard(req, res));

router.get("/users", (req, res) => adminPanelController.listUsers(req, res));
router.patch("/users/:id/suspend", (req, res) => adminPanelController.suspendUser(req, res));
router.patch("/users/:id/unsuspend", (req, res) => adminPanelController.unsuspendUser(req, res));

router.get("/sessions", (req, res) => adminPanelController.listSessions(req, res));

router.get("/reports", (req, res) => adminPanelController.listReports(req, res));
router.patch("/reports/:id", (req, res) => adminPanelController.updateReportStatus(req, res));

export default router;
