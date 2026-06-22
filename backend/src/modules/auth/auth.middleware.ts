import { Request, Response, NextFunction } from "express";
import { TokenUtil } from "../../common/utils/token.util";

const STUDENT_EMAIL_DOMAINS = ["university.edu", "student.ac.lk"];

const tokenUtil = new TokenUtil();

export function authenticate(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ message: "Missing or malformed Authorization header" });
    return;
  }

  const token = authHeader.slice(7);

  const payload = tokenUtil.verifyAccessToken(token);
  if (!payload) {
    res.status(401).json({ message: "Invalid or expired access token" });
    return;
  }

  req.user = payload; // typed via Express augmentation below
  next();
}

export function studentOnly(req: Request, res: Response, next: NextFunction) {
  const email: string = req.user?.email ?? "";
  const isStudent = STUDENT_EMAIL_DOMAINS.some((d) => email.endsWith(`@${d}`));

  if (!isStudent) {
    res.status(403).json({ message: "Access restricted to students only" });
    return;
  }

  next();
}

//Express type augmentation
declare global {
  namespace Express {
    interface Request {
      user?: { sub: string; email: string };
    }
  }
}