import jwt from "jsonwebtoken";
import { addDays } from "date-fns";

interface TokenPayload {
  sub: string;
  email: string;
}

const ACCESS_SECRET  = process.env.JWT_ACCESS_SECRET!;
const REFRESH_SECRET = process.env.JWT_REFRESH_SECRET!;
const ACCESS_TTL     = "15m";
const REFRESH_TTL_DAYS = 7;

export class TokenUtil {
  generateTokenPair(payload: TokenPayload) {
    const accessToken = jwt.sign(payload, ACCESS_SECRET, {
      expiresIn: ACCESS_TTL,
    });

    const refreshToken = jwt.sign(payload, REFRESH_SECRET, {
      expiresIn: `${REFRESH_TTL_DAYS}d`,
    });

    return { accessToken, refreshToken };
  }

  verifyAccessToken(token: string): TokenPayload | null {
    try {
      return jwt.verify(token, ACCESS_SECRET) as TokenPayload;
    } catch {
      return null;
    }
  }

  refreshTokenExpiry(): Date {
    return addDays(new Date(), REFRESH_TTL_DAYS);
  }
}