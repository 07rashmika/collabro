import { Request, Response, NextFunction } from "express";
import { TokenUtil } from "../utils/token.util";

const tokenUtil = new TokenUtil();

export function jwtGuard(req: Request, res: Response, next: NextFunction) {
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

  req.user = payload;
  next();
}