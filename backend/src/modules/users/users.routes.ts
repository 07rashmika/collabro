import { Router, Request, Response, NextFunction } from "express";
import multer from "multer";
import path from "path";
import crypto from "crypto";
import { UsersController } from "./users.controller";
import { UsersService } from "./users.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { jwtGuard } from "../../common/guards/jwt.guard";
import { adminGuard } from "../../common/guards/admin.guard";
import { AppError } from "../../common/errors/app-error";

const router = Router();

const prisma = PrismaService.getInstance();
const usersService = new UsersService(prisma);
const usersController = new UsersController(usersService);

const MAX_AVATAR_SIZE_BYTES = 5 * 1024 * 1024; // 5MB
const ALLOWED_AVATAR_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"]);

const avatarUpload = multer({
  storage: multer.diskStorage({
    destination: path.join(__dirname, "../../../uploads/avatars"),
    filename: (_req, file, cb) => {
      const ext = path.extname(file.originalname) || "";
      cb(null, `${crypto.randomUUID()}${ext}`);
    },
  }),
  limits: { fileSize: MAX_AVATAR_SIZE_BYTES },
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_AVATAR_MIME_TYPES.has(file.mimetype)) {
      cb(new AppError(`Unsupported image type: ${file.mimetype}`, 400));
      return;
    }
    cb(null, true);
  },
});

function uploadAvatarMiddleware(req: Request, res: Response, next: NextFunction) {
  avatarUpload.single("avatar")(req, res, (err: unknown) => {
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

router.use(jwtGuard);

// Me
router.get("/me", (req, res) => usersController.getMe(req, res));
router.patch("/me", (req, res) => usersController.updateMe(req, res));
router.delete("/me", (req, res) => usersController.deleteMe(req, res));

// Avatar
router.post("/me/avatar", uploadAvatarMiddleware, (req, res) =>
  usersController.uploadAvatar(req, res)
);
router.delete("/me/avatar", (req, res) => usersController.deleteAvatar(req, res));

// All users
router.get("/", (req, res) => usersController.getAllUsers(req, res));

// Single user
router.get("/:id", (req, res) => usersController.getUserById(req, res));

// Admin only
router.delete("/:id", adminGuard, (req, res) =>
  usersController.deleteUser(req, res)
);

export default router;