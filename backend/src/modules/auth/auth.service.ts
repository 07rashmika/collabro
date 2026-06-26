import bcrypt from "bcrypt";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";
import { RegisterDto, LoginDto } from "./auth.schema";

const SALT_ROUNDS = 12;

export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tokenUtil: TokenUtil
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
      },
    });

    if (!user) {
      throw new Error("Invalid email or password");
    }

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new Error("Invalid email or password");
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
}