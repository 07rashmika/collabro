import { Router } from "express";
import { SessionsController } from "./sessions.controller";
import { SessionsService } from "./sessions.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { jwtGuard } from "../../common/guards/jwt.guard";
import { studentDomainGuard } from "../../common/guards/student-domain.guard";

const router = Router();

const prisma = PrismaService.getInstance();
const sessionsService = new SessionsService(prisma);
const sessionsController = new SessionsController(sessionsService);

router.use(jwtGuard, studentDomainGuard);

// Sessions
router.get("/", (req, res) => sessionsController.getMySessions(req, res));
router.get("/:id", (req, res) => sessionsController.getSessionById(req, res));
router.post("/", (req, res) => sessionsController.createSession(req, res));
router.patch("/:id", (req, res) => sessionsController.updateSession(req, res));
router.delete("/:id", (req, res) => sessionsController.deleteSession(req, res));

// Session status
router.patch("/:id/close", (req, res) =>
  sessionsController.closeSession(req, res)
);

// Participants
router.post("/:id/participants/:userId", (req, res) =>
  sessionsController.addParticipant(req, res)
);
router.delete("/:id/participants/:userId", (req, res) =>
  sessionsController.removeParticipant(req, res)
);

// Messages
router.get("/:id/messages", (req, res) =>
  sessionsController.getMessages(req, res)
);
router.post("/:id/messages", (req, res) =>
  sessionsController.sendMessage(req, res)
);
router.delete("/:id/messages/:messageId", (req, res) =>
  sessionsController.deleteMessage(req, res)
);

export default router;