import { Request, Response, NextFunction } from "express";

export function adminGuard(req: Request, res: Response, next: NextFunction) {
  const role = req.user?.role;

  if (role !== "ADMIN") {
    res.status(403).json({ message: "Access restricted to admins only" });
    return;
  }

  next();
}