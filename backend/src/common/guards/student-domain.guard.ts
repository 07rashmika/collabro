import { Request, Response, NextFunction } from "express";
import { STUDENT_EMAIL_DOMAINS } from "../config/student-domains";

export function studentDomainGuard(
  req: Request,
  res: Response,
  next: NextFunction
) {
  const email = req.user?.email ?? "";
  const isStudent = STUDENT_EMAIL_DOMAINS.some((d) =>
    email.endsWith(`@${d}`)
  );

  if (!isStudent) {
    res.status(403).json({ message: "Access restricted to students only" });
    return;
  }

  next();
}