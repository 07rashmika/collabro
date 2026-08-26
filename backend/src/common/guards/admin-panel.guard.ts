import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

const ADMIN_PANEL_ROLE = "ADMIN_PANEL";

interface AdminPanelPayload {
  role: typeof ADMIN_PANEL_ROLE;
  email: string;
}

export function adminPanelGuard(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ message: "Missing or malformed Authorization header" });
    return;
  }

  const token = authHeader.slice(7);

  try {
    const payload = jwt.verify(token, process.env.ADMIN_JWT_SECRET!) as AdminPanelPayload;
    if (payload.role !== ADMIN_PANEL_ROLE) {
      res.status(403).json({ message: "Not an admin session" });
      return;
    }
    req.adminEmail = payload.email;
    next();
  } catch {
    res.status(401).json({ message: "Invalid or expired admin session" });
  }
}

export function signAdminPanelToken(email: string): string {
  return jwt.sign({ role: ADMIN_PANEL_ROLE, email }, process.env.ADMIN_JWT_SECRET!, {
    expiresIn: "12h",
  });
}

declare global {
  namespace Express {
    interface Request {
      adminEmail?: string;
    }
  }
}
