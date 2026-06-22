import { Router } from "express";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";
import { authenticate } from "./auth.middleware";

const router = Router();

// Dependency wiring
const prisma = PrismaService.getInstance();
const tokenUtil = new TokenUtil();
const authService = new AuthService(prisma, tokenUtil);
const authController = new AuthController(authService);

// Public routes
router.post("/register", (req, res) => authController.register(req, res));
router.post("/login",    (req, res) => authController.login(req, res));
router.post("/refresh",  (req, res) => authController.refresh(req, res));

// Protected routes
router.post("/logout", authenticate, (req, res) => authController.logout(req, res));

export default router;