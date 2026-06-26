import { Request, Response, NextFunction } from "express";
import { AppError } from "../errors/app-error";

export function httpExceptionFilter(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction
) {
  if (err instanceof AppError) {
    console.error(`[${req.method}] ${req.path} → ${err.statusCode}: ${err.message}`);
    res.status(err.statusCode).json({ message: err.message });
    return;
  }

  const message = err instanceof Error ? err.message : "Internal server error";
  console.error(`[${req.method}] ${req.path} → 500: ${message}`);
  res.status(500).json({ message });
}