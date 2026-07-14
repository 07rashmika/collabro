import { Router } from "express";
import { StudyAreasController } from "./study-areas.controller";
import { StudyAreasService }    from "./study-areas.service";
import { PrismaService }        from "../../infrastructure/database/prisma.service";
import { jwtGuard }             from "../../common/guards/jwt.guard";
import { studentDomainGuard }   from "../../common/guards/student-domain.guard";
import { adminGuard }           from "../../common/guards/admin.guard";

const router = Router();

const prisma               = PrismaService.getInstance();
const studyAreasService    = new StudyAreasService(prisma);
const studyAreasController = new StudyAreasController(studyAreasService);

// All routes require a valid JWT and a student email domain
router.use(jwtGuard, studentDomainGuard);

// ── Read-only (all students) ──────────────────────────────────────────────────
router.get("/",    (req, res) => studyAreasController.getAllStudyAreas(req, res));

// Lets a student type a study area that isn't in the catalog yet — creates
// it if missing (case-insensitive dedupe) instead of requiring an admin.
router.post("/find-or-create", (req, res) => studyAreasController.findOrCreateStudyArea(req, res));

router.get("/:id", (req, res) => studyAreasController.getStudyAreaById(req, res));

// ── Write operations (admin only) ─────────────────────────────────────────────
router.post(  "/",    adminGuard, (req, res) => studyAreasController.createStudyArea(req, res));
router.patch( "/:id", adminGuard, (req, res) => studyAreasController.updateStudyArea(req, res));
router.delete("/:id", adminGuard, (req, res) => studyAreasController.deleteStudyArea(req, res));

// Seed is admin-only — run once after first deploy
router.post("/seed", adminGuard, (req, res) => studyAreasController.seedStudyAreas(req, res));

export default router;
