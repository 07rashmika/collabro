import { Router } from "express";
import { NotesController } from "./notes.controller";
import { NotesService } from "./notes.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { jwtGuard } from "../../common/guards/jwt.guard";
import { studentDomainGuard } from "../../common/guards/student-domain.guard";

const router = Router();

const prisma = PrismaService.getInstance();
const notesService = new NotesService(prisma);
const notesController = new NotesController(notesService);

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

export default router;