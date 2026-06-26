import { Router } from "express";
import { ProfilesController } from "./profiles.controller";
import { ProfilesService } from "./profiles.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { authenticate } from "../auth/auth.middleware";
import { studentDomainGuard } from "../../common/guards/student-domain.guard";

const router = Router();

// Dependency wiring
const prisma = PrismaService.getInstance();
const profilesService = new ProfilesService(prisma);
const profilesController = new ProfilesController(profilesService);

// All profile routes require auth + student check
router.use(authenticate, studentDomainGuard);

// My profile
router.get("/me", (req, res) => profilesController.getMyProfile(req, res));
router.post("/", (req, res) => profilesController.createProfile(req, res));
router.patch("/", (req, res) => profilesController.updateProfile(req, res));
router.delete("/", (req, res) => profilesController.deleteProfile(req, res));

// Skills
router.post("/skills", (req, res) => profilesController.addSkill(req, res));
router.delete("/skills", (req, res) => profilesController.removeSkill(req, res));

// View another student's profile
router.get("/:userId", (req, res) =>
  profilesController.getProfileByUserId(req, res)
);

export default router;