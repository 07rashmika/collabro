import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";

const ADMIN_PANEL_ROLE = "ADMIN_PANEL";

interface AdminPanelPayload {
  role: typeof ADMIN_PANEL_ROLE;
  email: string;
}

/// Guards the web admin panel's API — a single operator identity read from
/// ADMIN_EMAIL/ADMIN_PASSWORD (see admin-panel.service.ts), signed with its
/// own secret so this session is entirely separate from student JWTs and
/// can't be confused with the User-row-based Role.ADMIN used elsewhere.
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
