import { Router } from "express";
import { ConnectionsController } from "./connections.controller";
import { ConnectionsService } from "./connections.service";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { jwtGuard } from "../../common/guards/jwt.guard";

const router = Router();

const prisma = PrismaService.getInstance();
const connectionsService = new ConnectionsService(prisma);
const connectionsController = new ConnectionsController(connectionsService);

router.use(jwtGuard);

router.get("/mine", (req, res) => connectionsController.getMyConnections(req, res));
router.post("/", (req, res) => connectionsController.sendRequest(req, res));
router.delete("/", (req, res) => connectionsController.cancelRequest(req, res));
router.post("/:id/accept", (req, res) => connectionsController.accept(req, res));
router.post("/:id/decline", (req, res) => connectionsController.decline(req, res));

export default router;
