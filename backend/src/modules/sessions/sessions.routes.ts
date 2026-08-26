import { Router, Request, Response, NextFunction } from "express";
import multer from "multer";
import path from "path";
import crypto from "crypto";
import { SessionsController } from "./sessions.controller";
import { SessionsService } from "./sessions.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { jwtGuard } from "../../common/guards/jwt.guard";
import { AppError } from "../../common/errors/app-error";
import { SummarizerClient } from "../summaries/summarizer.client";
import { SummariesService } from "../summaries/summaries.service";
import { TranscriptionClient } from "./transcription.client";
import { ReportsService } from "../reports/reports.service";
import { ReportsController } from "../reports/reports.controller";

const router = Router();

const prisma = PrismaService.getInstance();
const summarizerClient = new SummarizerClient(
  process.env.SUMMARIZER_URL || "http://localhost:8000",
);
const transcriptionClient = new TranscriptionClient(
  process.env.SUMMARIZER_URL || "http://localhost:8000",
);
const summariesService = new SummariesService(summarizerClient);
const sessionsService = new SessionsService(
  prisma,
  summariesService,
  transcriptionClient,
);
const sessionsController = new SessionsController(sessionsService);
const reportsService = new ReportsService(prisma);
const reportsController = new ReportsController(reportsService);

const MAX_RECORDING_TRACKS = 2;
const MAX_RECORDING_SIZE_BYTES = 200 * 1024 * 1024;
const ALLOWED_AUDIO_MIME_TYPES = new Set([
  "audio/mp4",
  "audio/m4a",
  "audio/x-m4a",
  "audio/aac",
]);

const recordingUpload = multer({
  storage: multer.diskStorage({
    destination: path.join(__dirname, "../../../uploads/sessions/recordings"),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname) || ".mp4";
      cb(null, `${crypto.randomUUID()}${ext}`);
    },
  }),
  limits: {
    fileSize: MAX_RECORDING_SIZE_BYTES,
    files: MAX_RECORDING_TRACKS,
  },
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_AUDIO_MIME_TYPES.has(file.mimetype)) {
      cb(new AppError(`Unsupported audio type: ${file.mimetype}`, 400));
      return;
    }
    cb(null, true);
  },
});

function uploadRecordingMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  recordingUpload.array("tracks", MAX_RECORDING_TRACKS)(
    req,
    res,
    (err: unknown) => {
      if (err instanceof multer.MulterError) {
        next(new AppError(err.message, 400));
        return;
      }
      if (err) {
        next(err);
        return;
      }
      next();
    },
  );
}

setInterval(() => {
  sessionsService.expireStaleSessions().catch((err) => {
    console.error("[Sessions] Failed to expire stale sessions", err);
  });
}, 60_000);

router.use(jwtGuard);

router.get("/", (req, res) => sessionsController.getMySessions(req, res));
router.get("/discover", (req, res) =>
  sessionsController.discoverSessions(req, res),
);
router.get("/saved", (req, res) =>
  sessionsController.getSavedSessions(req, res),
);
router.get("/user/:userId", (req, res) =>
  sessionsController.getSessionsByUser(req, res),
);
router.get("/:id", (req, res) => sessionsController.getSessionById(req, res));
router.post("/", (req, res) => sessionsController.createSession(req, res));
router.post("/join", (req, res) => sessionsController.joinByCode(req, res));
router.patch("/:id", (req, res) => sessionsController.updateSession(req, res));
router.delete("/:id", (req, res) => sessionsController.deleteSession(req, res));

router.patch("/:id/close", (req, res) =>
  sessionsController.closeSession(req, res),
);

router.post("/:id/save", (req, res) =>
  sessionsController.saveSession(req, res),
);
router.delete("/:id/save", (req, res) =>
  sessionsController.unsaveSession(req, res),
);

router.get("/:id/password", (req, res) =>
  sessionsController.getSessionPassword(req, res),
);

router.post("/:id/participants/:userId", (req, res) =>
  sessionsController.addParticipant(req, res),
);
router.delete("/:id/participants/:userId", (req, res) =>
  sessionsController.removeParticipant(req, res),
);

router.get("/:id/messages", (req, res) =>
  sessionsController.getMessages(req, res),
);
router.post("/:id/messages", (req, res) =>
  sessionsController.sendMessage(req, res),
);
router.delete("/:id/messages/:messageId", (req, res) =>
  sessionsController.deleteMessage(req, res),
);

router.post("/:id/reports", (req, res) =>
  reportsController.createReport(req, res),
);

router.get("/:id/ice-servers", (req, res) =>
  sessionsController.getIceServers(req, res),
);

router.post("/:id/summary", (req, res) =>
  sessionsController.generateSummary(req, res),
);

router.post("/:id/recording", uploadRecordingMiddleware, (req, res) =>
  sessionsController.uploadRecording(req, res),
);

export default router;
