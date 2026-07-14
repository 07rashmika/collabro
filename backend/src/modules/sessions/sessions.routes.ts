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
// Literal paths must be registered before "/:id" so they aren't swallowed
// as an id lookup (e.g. GET /sessions/discover would otherwise try to find
// a session with id "discover").
router.get("/discover", (req, res) => sessionsController.discoverSessions(req, res));
router.get("/saved", (req, res) => sessionsController.getSavedSessions(req, res));
router.get("/:id", (req, res) => sessionsController.getSessionById(req, res));
router.post("/", (req, res) => sessionsController.createSession(req, res));
router.post("/join", (req, res) => sessionsController.joinByCode(req, res));
router.patch("/:id", (req, res) => sessionsController.updateSession(req, res));
router.delete("/:id", (req, res) => sessionsController.deleteSession(req, res));

// Session status
router.patch("/:id/close", (req, res) =>
  sessionsController.closeSession(req, res)
);

// Bookmarks
router.post("/:id/save", (req, res) => sessionsController.saveSession(req, res));
router.delete("/:id/save", (req, res) => sessionsController.unsaveSession(req, res));

// Owner-only: view the decrypted session password
router.get("/:id/password", (req, res) => sessionsController.getSessionPassword(req, res));

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

// Video calling (ZegoCloud)
router.get("/:id/zego-token", (req, res) =>
  sessionsController.getZegoToken(req, res)
);

export default router;