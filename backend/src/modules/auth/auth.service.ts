import bcrypt from "bcrypt";
import { addMinutes } from "date-fns";
import { OAuth2Client } from "google-auth-library";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";
import { MailService } from "../../common/services/mail.service";
import { AppError } from "../../common/errors/app-error";
import {
  generateResetCode,
  generateResetSessionToken,
  hashToken,
} from "../../common/utils/password-reset-code.util";
import { RegisterDto, LoginDto } from "./auth.schema";

const SALT_ROUNDS = 12;
const RESET_CODE_TTL_MINUTES = 15;
const RESET_SESSION_TTL_MINUTES = 10;
const RESET_CODE_MAX_ATTEMPTS = 5;
const RESET_CODE_RESEND_COOLDOWN_SECONDS = 30;
const MAX_LOGIN_ATTEMPTS = 5;
const ACCOUNT_LOCK_MINUTES = 15;
const googleClient = new OAuth2Client();

export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenUtil: TokenUtil,
    private readonly mailService: MailService
  ) {}

  async register(dto: RegisterDto) {
    const existing = await this.prisma.client.user.findUnique({
      where: { email: dto.email },
    });

    if (existing) {
      throw new Error("A user with this email already exists");
    }

    const passwordHash = await bcrypt.hash(dto.password, SALT_ROUNDS);

    const user = await this.prisma.client.user.create({
      data: {
        name: dto.name,
        email: dto.email,
        passwordHash,
      },
      select: { id: true, name: true, email: true, role: true, createdAt: true },
    });

    const { accessToken, refreshToken } = this.tokenUtil.generateTokenPair({
      sub: user.id,
      email: user.email,
      role: user.role,
    });

    await this.prisma.client.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: this.tokenUtil.refreshTokenExpiry(),
      },
    });

    return { user, accessToken, refreshToken };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.client.user.findUnique({
      where: { email: dto.email },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        passwordHash: true,
        failedLoginAttempts: true,
        lockedUntil: true,
      },
    });

    if (!user) {
      throw new Error("Invalid email or password");
    }

    if (user.lockedUntil && user.lockedUntil > new Date()) {
      const minutesLeft = Math.ceil((user.lockedUntil.getTime() - Date.now()) / 60000);
      throw new AppError(
        `Account locked due to too many failed login attempts. Try again in ${minutesLeft} minute${minutesLeft === 1 ? "" : "s"}.`,
        423
      );
    }

    if (!user.passwordHash) {
      throw new Error("This account uses Google Sign-In. Please continue with Google.");
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      const attempts = user.failedLoginAttempts + 1;

      if (attempts >= MAX_LOGIN_ATTEMPTS) {
        await this.prisma.client.user.update({
          where: { id: user.id },
          data: {
            failedLoginAttempts: 0,
            lockedUntil: addMinutes(new Date(), ACCOUNT_LOCK_MINUTES),
          },
        });
        throw new AppError(
          `Too many failed login attempts. Account locked for ${ACCOUNT_LOCK_MINUTES} minutes.`,
          423
        );
      }

      await this.prisma.client.user.update({
        where: { id: user.id },
        data: { failedLoginAttempts: attempts },
      });
      throw new Error("Invalid email or password");
    }

    if (user.failedLoginAttempts > 0 || user.lockedUntil) {
      await this.prisma.client.user.update({
        where: { id: user.id },
        data: { failedLoginAttempts: 0, lockedUntil: null },
      });
    }

    const { accessToken, refreshToken } = this.tokenUtil.generateTokenPair({
      sub: user.id,
      email: user.email,
      role: user.role,
    });

    // Rotate: invalidate all old refresh tokens for this user, issue new one
    await this.prisma.client.refreshToken.deleteMany({
      where: { userId: user.id },
    });

    await this.prisma.client.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: this.tokenUtil.refreshTokenExpiry(),
      },
    });

    return {
      user: { id: user.id, name: user.name, email: user.email },
      accessToken,
      refreshToken,
    };
  }

  async loginWithGoogle(idToken: string) {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    if (!payload?.email || !payload.email_verified) {
      throw new Error("Google account email is missing or unverified");
    }

    const googleId = payload.sub;
    const email = payload.email;
    const name = payload.name ?? email.split("@")[0];

    let user = await this.prisma.client.user.findUnique({ where: { googleId } });

    if (!user) {
      const existingByEmail = await this.prisma.client.user.findUnique({ where: { email } });

      user = existingByEmail
        ? await this.prisma.client.user.update({
            where: { id: existingByEmail.id },
            data: { googleId },
          })
        : await this.prisma.client.user.create({
            data: { name, email, googleId },
          });
    }

    const { accessToken, refreshToken } = this.tokenUtil.generateTokenPair({
      sub: user.id,
      email: user.email,
      role: user.role,
    });

    // Rotate: invalidate all old refresh tokens for this user, issue new one
    await this.prisma.client.refreshToken.deleteMany({
      where: { userId: user.id },
    });

    await this.prisma.client.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: this.tokenUtil.refreshTokenExpiry(),
      },
    });

    return {
      user: { id: user.id, name: user.name, email: user.email },
      accessToken,
      refreshToken,
    };
  }

  async refresh(rawToken: string) {
    const stored = await this.prisma.client.refreshToken.findUnique({
      where: { token: rawToken },
      include: { user: true },
    });

    if (!stored || stored.expiresAt < new Date()) {
      throw new Error("Invalid or expired refresh token");
    }

    const { accessToken, refreshToken: newRefreshToken } =
      this.tokenUtil.generateTokenPair({
        sub: stored.user.id,
        email: stored.user.email,
        role: stored.user.role,
      });

    // Rotate refresh token
    await this.prisma.client.refreshToken.update({
      where: { id: stored.id },
      data: {
        token: newRefreshToken,
        expiresAt: this.tokenUtil.refreshTokenExpiry(),
      },
    });

    return { accessToken, refreshToken: newRefreshToken };
  }

  async logout(userId: string) {
    await this.prisma.client.refreshToken.deleteMany({
      where: { userId },
    });
  }

  /// Always responds the same way whether or not the email exists, so the
  /// endpoint can't be used to enumerate registered accounts. Only sends
  /// mail (and so only surfaces a mail-config 503) when a matching user
  /// is actually found.
  async forgotPassword(email: string) {
    const genericResult = {
      message: "If an account exists for that email, we've sent a 6-digit reset code.",
    };

    const user = await this.prisma.client.user.findUnique({ where: { email } });
    if (!user) {
      return genericResult;
    }

    const outstanding = await this.prisma.client.passwordResetToken.findFirst({
      where: { userId: user.id, usedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: "desc" },
    });
    if (
      outstanding &&
      outstanding.createdAt.getTime() > Date.now() - RESET_CODE_RESEND_COOLDOWN_SECONDS * 1000
    ) {
      throw new AppError("Please wait a moment before requesting another code", 429);
    }

    const code = generateResetCode();
    await this.prisma.client.passwordResetToken.create({
      data: {
        userId: user.id,
        codeHash: hashToken(code),
        expiresAt: addMinutes(new Date(), RESET_CODE_TTL_MINUTES),
      },
    });

    await this.mailService.sendPasswordResetCode(user.email, user.name, code);

    return genericResult;
  }

  /// Step 2 of 3. Checks the emailed code and, if correct, exchanges it for
  /// an opaque reset-session token — the code itself is spent at this point
  /// and can't be reused; only the returned token unlocks resetPassword().
  async verifyResetCode(email: string, code: string) {
    const invalidCodeError = new AppError("Invalid or expired reset code", 400);

    const user = await this.prisma.client.user.findUnique({ where: { email } });
    if (!user) {
      throw invalidCodeError;
    }

    const token = await this.prisma.client.passwordResetToken.findFirst({
      where: { userId: user.id, usedAt: null },
      orderBy: { createdAt: "desc" },
    });

    if (!token || token.expiresAt < new Date()) {
      throw invalidCodeError;
    }
    if (token.attempts >= RESET_CODE_MAX_ATTEMPTS) {
      throw new AppError("Too many incorrect attempts. Request a new code.", 400);
    }

    if (token.codeHash !== hashToken(code)) {
      await this.prisma.client.passwordResetToken.update({
        where: { id: token.id },
        data: { attempts: { increment: 1 } },
      });
      throw invalidCodeError;
    }

    const resetToken = generateResetSessionToken();
    await this.prisma.client.passwordResetToken.update({
      where: { id: token.id },
      data: {
        verifiedAt: new Date(),
        resetTokenHash: hashToken(resetToken),
        // Fresh window for the final step, independent of how long step 1→2 took.
        expiresAt: addMinutes(new Date(), RESET_SESSION_TTL_MINUTES),
      },
    });

    return { resetToken };
  }

  /// Step 3 of 3. Only accepts a token minted by verifyResetCode() — never
  /// the raw email/code — so the code can't be replayed against this step.
  async resetPassword(resetToken: string, newPassword: string) {
    const invalidSessionError = new AppError(
      "Your reset session has expired. Please start again.",
      400
    );

    const token = await this.prisma.client.passwordResetToken.findFirst({
      where: {
        resetTokenHash: hashToken(resetToken),
        usedAt: null,
        verifiedAt: { not: null },
        expiresAt: { gt: new Date() },
      },
    });

    if (!token) {
      throw invalidSessionError;
    }

    const passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS);

    await this.prisma.client.user.update({
      where: { id: token.userId },
      data: { passwordHash, failedLoginAttempts: 0, lockedUntil: null },
    });
    await this.prisma.client.passwordResetToken.update({
      where: { id: token.id },
      data: { usedAt: new Date() },
    });

    // Reset invalidates every existing session, on every device.
    await this.prisma.client.refreshToken.deleteMany({ where: { userId: token.userId } });
  }
}