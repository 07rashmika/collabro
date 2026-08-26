import { Router } from "express";
import { MatchingController } from "./matching.controller";
import { MatchingService } from "./matching.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { jwtGuard } from "../../common/guards/jwt.guard";

const router = Router();

const prisma = PrismaService.getInstance();
const matchingService = new MatchingService(prisma);
const matchingController = new MatchingController(matchingService);

router.use(jwtGuard);

router.get("/suggestions", (req, res) =>
  matchingController.getSuggestions(req, res)
);

router.get("/score/:userId", (req, res) =>
  matchingController.getMatchById(req, res)
);

export default router;
