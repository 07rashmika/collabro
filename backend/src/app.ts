import express from "express";
import cors from "cors";
import path from "path";

import authRoutes from "./modules/auth/auth.routes";
import profileRoutes from "./modules/profiles/profiles.routes";
import skillsRoutes from "./modules/skills/skills.routes";
import studyAreasRoutes from "./modules/study-areas/study-areas.routes";
import notesRoutes from "./modules/notes/notes.routes";
import sessionRoutes from "./modules/sessions/sessions.routes";
import userRoutes from "./modules/users/users.routes";
import matchingRoutes from "./modules/matching/matching.routes";
import connectionsRoutes from "./modules/connections/connections.routes";
import notificationsRoutes from "./modules/notifications/notifications.routes";

import { loggingInterceptor } from "./common/interceptors/logging.interceptor";
import { httpExceptionFilter } from "./common/filters/http-exception.filter";

const app = express();

// Global middleware
app.use(cors());
app.use(express.json());
app.use(loggingInterceptor);
app.use("/uploads", express.static(path.join(__dirname, "../uploads")));

// Health check
app.get("/", (_req, res) => {
  res.json({ status: "ok", service: "collabro-api" });
});

// Feature routes
app.use("/auth",     authRoutes);
app.use("/profiles", profileRoutes);
app.use("/skills",   skillsRoutes);
app.use("/study-areas", studyAreasRoutes);
app.use("/notes",    notesRoutes);
app.use("/sessions", sessionRoutes);
app.use("/users",    userRoutes);
app.use("/matching", matchingRoutes);
app.use("/connections",   connectionsRoutes);
app.use("/notifications", notificationsRoutes);

// Global error handler
app.use(httpExceptionFilter);

export default app;