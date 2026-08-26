import crypto from "crypto";

export function generateResetCode(): string {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, "0");
}

export function generateResetSessionToken(): string {
  return crypto.randomBytes(32).toString("hex");
}

export function hashToken(value: string): string {
  return crypto.createHash("sha256").update(value).digest("hex");
}
