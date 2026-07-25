import { Router, Request, Response, NextFunction } from "express";
import multer from "multer";
import path from "path";
import crypto from "crypto";
import { NotesController } from "./notes.controller";
import { NotesService } from "./notes.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { jwtGuard } from "../../common/guards/jwt.guard";
import { studentDomainGuard } from "../../common/guards/student-domain.guard";
import { AppError } from "../../common/errors/app-error";
import { SummarizerClient } from "../summaries/summarizer.client";
import { SummariesService } from "../summaries/summaries.service";

const router = Router();

const prisma = PrismaService.getInstance();
const summarizerClient = new SummarizerClient(process.env.SUMMARIZER_URL || "http://localhost:8000");
const summariesService = new SummariesService(summarizerClient);
const notesService = new NotesService(prisma, summariesService);
const notesController = new NotesController(notesService);

const MAX_PHOTOS_PER_UPLOAD = 6;
const MAX_PHOTO_SIZE_BYTES = 10 * 1024 * 1024; // 10MB
const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"]);

const upload = multer({
  storage: multer.diskStorage({
    destination: path.join(__dirname, "../../../uploads/notes"),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname) || "";
      cb(null, `${crypto.randomUUID()}${ext}`);
    },
  }),
  limits: {
    fileSize: MAX_PHOTO_SIZE_BYTES,
    files: MAX_PHOTOS_PER_UPLOAD,
  },
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
      cb(new AppError(`Unsupported image type: ${file.mimetype}`, 400));
      return;
    }
    cb(null, true);
  },
});

function uploadPhotosMiddleware(req: Request, res: Response, next: NextFunction) {
  upload.array("photos", MAX_PHOTOS_PER_UPLOAD)(req, res, (err: unknown) => {
    if (err instanceof multer.MulterError) {
      next(new AppError(err.message, 400));
      return;
    }
    if (err) {
      next(err);
      return;
    }
    next();
  });
}

router.use(jwtGuard, studentDomainGuard);

// My notes
router.get("/me", (req, res) => notesController.getMyNotes(req, res));
router.get("/me/tags", (req, res) => notesController.getAllTags(req, res));

// Public notes discovery
router.get("/public", (req, res) => notesController.getPublicNotes(req, res));

// Notes by a specific student
router.get("/user/:userId", (req, res) =>
  notesController.getNotesByUser(req, res)
);

// Single note
router.get("/:id", (req, res) => notesController.getNoteById(req, res));
router.post("/", (req, res) => notesController.createNote(req, res));
router.patch("/:id", (req, res) => notesController.updateNote(req, res));
router.delete("/:id", (req, res) => notesController.deleteNote(req, res));

// Toggle public / private
router.patch("/:id/visibility", (req, res) =>
  notesController.toggleVisibility(req, res)
);

// AI summary
router.post("/:id/summary", (req, res) =>
  notesController.generateSummary(req, res)
);

// Photos
router.post("/:id/photos", uploadPhotosMiddleware, (req, res) =>
  notesController.uploadPhotos(req, res)
);
router.delete("/:id/photos/:photoId", (req, res) =>
  notesController.deletePhoto(req, res)
);

export default router;
