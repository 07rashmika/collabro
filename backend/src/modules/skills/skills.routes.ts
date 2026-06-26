import { Router } from "express";
import { SkillsController }   from "./skills.controller";
import { SkillsService }      from "./skills.service";
import { PrismaService }      from "../../infrastructure/database/prisma.service";
import { jwtGuard }           from "../../common/guards/jwt.guard";
import { studentDomainGuard } from "../../common/guards/student-domain.guard";
import { adminGuard }         from "../../common/guards/admin.guard";

const router = Router();

const prisma           = PrismaService.getInstance();
const skillsService    = new SkillsService(prisma);
const skillsController = new SkillsController(skillsService);

// All routes require a valid JWT and a student email domain
router.use(jwtGuard, studentDomainGuard);

// ── Read-only (all students) ──────────────────────────────────────────────────
router.get("/categories", (req, res) => skillsController.getCategories(req, res));
router.get("/",           (req, res) => skillsController.getAllSkills(req, res));
router.get("/:id",        (req, res) => skillsController.getSkillById(req, res));

// ── Write operations (admin only) ─────────────────────────────────────────────
router.post(  "/",    adminGuard, (req, res) => skillsController.createSkill(req, res));
router.patch( "/:id", adminGuard, (req, res) => skillsController.updateSkill(req, res));
router.delete("/:id", adminGuard, (req, res) => skillsController.deleteSkill(req, res));

// Seed is admin-only — run once after first deploy
router.post("/seed", adminGuard, (req, res) => skillsController.seedSkills(req, res));

export default router;