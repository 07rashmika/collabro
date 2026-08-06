import { Router } from "express";
import { UsersController } from "./users.controller";
import { UsersService } from "./users.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { jwtGuard } from "../../common/guards/jwt.guard";
import { adminGuard } from "../../common/guards/admin.guard";

const router = Router();

const prisma = PrismaService.getInstance();
const usersService = new UsersService(prisma);
const usersController = new UsersController(usersService);

router.use(jwtGuard);

// Me
router.get("/me", (req, res) => usersController.getMe(req, res));
router.patch("/me", (req, res) => usersController.updateMe(req, res));
router.delete("/me", (req, res) => usersController.deleteMe(req, res));

// All users
router.get("/", (req, res) => usersController.getAllUsers(req, res));

// Single user
router.get("/:id", (req, res) => usersController.getUserById(req, res));

// Admin only
router.delete("/:id", adminGuard, (req, res) =>
  usersController.deleteUser(req, res)
);

export default router;