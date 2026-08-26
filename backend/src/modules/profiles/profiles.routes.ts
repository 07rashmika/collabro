import { Router } from "express";
import { ProfilesController } from "./profiles.controller";
import { ProfilesService } from "./profiles.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { authenticate } from "../auth/auth.middleware";

const router = Router();

// Dependency wiring
const prisma = PrismaService.getInstance();
const profilesService = new ProfilesService(prisma);
const profilesController = new ProfilesController(profilesService);

router.use(authenticate);

router.get("/me", (req, res) => profilesController.getMyProfile(req, res));
router.post("/", (req, res) => profilesController.createProfile(req, res));
router.patch("/", (req, res) => profilesController.updateProfile(req, res));
router.delete("/", (req, res) => profilesController.deleteProfile(req, res));

router.post("/skills", (req, res) => profilesController.addSkill(req, res));
router.delete("/skills", (req, res) => profilesController.removeSkill(req, res));

router.post("/study-areas", (req, res) => profilesController.addStudyArea(req, res));
router.delete("/study-areas", (req, res) => profilesController.removeStudyArea(req, res));

router.get("/:userId", (req, res) =>
  profilesController.getProfileByUserId(req, res)
);

export default router;