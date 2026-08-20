import crypto from "crypto";

/// A 6-digit numeric code, e.g. "042917" — easy to type on mobile, no
/// deep-linking required. crypto.randomInt is used instead of Math.random
/// since this value is a security credential, not UI randomness.
export function generateResetCode(): string {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, "0");
}

/// Opaque token issued once a 6-digit code has been verified correct — the
/// final "set new password" step accepts this instead of the code, so the
/// code itself is only ever checked once (see PasswordResetToken.resetTokenHash).
export function generateResetSessionToken(): string {
  return crypto.randomBytes(32).toString("hex");
}

/// Only this hash is ever persisted — used for both the emailed code and the
/// reset-session token. SHA-256 (not bcrypt) is sufficient here: the secret
/// being hashed is high-entropy and server-generated, not a user password.
export function hashToken(value: string): string {
  return crypto.createHash("sha256").update(value).digest("hex");
}
