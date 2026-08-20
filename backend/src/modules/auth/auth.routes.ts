import { Router } from "express";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";
import { MailService } from "../../common/services/mail.service";
import { authenticate } from "./auth.middleware";

const router = Router();

// Dependency wiring
const prisma = PrismaService.getInstance();
const tokenUtil = new TokenUtil();
const mailService = new MailService();
const authService = new AuthService(prisma, tokenUtil, mailService);
const authController = new AuthController(authService);

// Public routes
router.post("/register", (req, res) => authController.register(req, res));
router.post("/login",    (req, res) => authController.login(req, res));
router.post("/google",   (req, res) => authController.googleLogin(req, res));
router.post("/refresh",  (req, res) => authController.refresh(req, res));
router.post("/forgot-password",   (req, res) => authController.forgotPassword(req, res));
router.post("/verify-reset-code", (req, res) => authController.verifyResetCode(req, res));
router.post("/reset-password",    (req, res) => authController.resetPassword(req, res));

// Protected routes
router.post("/logout", authenticate, (req, res) => authController.logout(req, res));

export default router;