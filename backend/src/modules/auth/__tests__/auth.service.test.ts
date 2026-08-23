import { AuthService } from "../auth.service";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";
import { AppError } from "../../../common/errors/app-error";
import { OAuth2Client } from "google-auth-library";

jest.mock("google-auth-library", () => ({
  OAuth2Client: jest.fn().mockImplementation(() => ({ verifyIdToken: jest.fn() })),
}));

jest.mock("bcrypt", () => ({
  hash: jest.fn(),
  compare: jest.fn(),
}));

jest.mock("../../../common/utils/password-reset-code.util", () => ({
  generateResetCode: jest.fn(() => "123456"),
  generateResetSessionToken: jest.fn(() => "reset-session-token"),
  hashToken: jest.fn((v: string) => `hashed:${v}`),
}));

import bcrypt from "bcrypt";

const mockedHash = bcrypt.hash as unknown as jest.Mock;
const mockedCompare = bcrypt.compare as unknown as jest.Mock;

// AuthService instantiates `new OAuth2Client()` once at module scope, so the
// mocked instance is captured from the constructor mock's recorded results.
const mockOAuthInstance = (OAuth2Client as unknown as jest.Mock).mock.results[0]
  .value as { verifyIdToken: jest.Mock };

function makeService(client: Record<string, unknown>) {
  const prisma = createMockPrismaService(client);
  const tokenUtil = {
    generateTokenPair: jest
      .fn()
      .mockReturnValue({ accessToken: "access-token", refreshToken: "refresh-token" }),
    refreshTokenExpiry: jest.fn().mockReturnValue(new Date("2026-09-01T00:00:00Z")),
    verifyAccessToken: jest.fn(),
  };
  const mailService = { sendPasswordResetCode: jest.fn().mockResolvedValue(undefined) };
  const service = new AuthService(prisma, tokenUtil as never, mailService as never);
  return { service, tokenUtil, mailService };
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe("AuthService.register", () => {
  it("rejects an email that's already registered", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "u1" }) });
    const { service } = makeService({ user, refreshToken: mockModel() });

    await expect(
      service.register({ name: "A", email: "a@x.com", password: "password1" })
    ).rejects.toThrow("A user with this email already exists");
  });

  it("creates a user, hashes the password, and returns a token pair", async () => {
    mockedHash.mockResolvedValue("hashed-pw");
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({
        id: "u1",
        name: "A",
        email: "a@x.com",
        role: "STUDENT",
        createdAt: new Date(),
      }),
    });
    const refreshToken = mockModel({ create: jest.fn().mockResolvedValue({}) });
    const { service, tokenUtil } = makeService({ user, refreshToken });

    const result = await service.register({ name: "A", email: "a@x.com", password: "password1" });

    expect(user.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ passwordHash: "hashed-pw" }) })
    );
    expect(tokenUtil.generateTokenPair).toHaveBeenCalledWith({
      sub: "u1",
      email: "a@x.com",
      role: "STUDENT",
    });
    expect(refreshToken.create).toHaveBeenCalled();
    expect(result).toEqual({
      user: expect.objectContaining({ id: "u1" }),
      accessToken: "access-token",
      refreshToken: "refresh-token",
    });
  });
});

describe("AuthService.login", () => {
  function baseUser(overrides: Record<string, unknown> = {}) {
    return {
      id: "u1",
      name: "A",
      email: "a@x.com",
      role: "STUDENT",
      passwordHash: "hashed-pw",
      failedLoginAttempts: 0,
      lockedUntil: null,
      ...overrides,
    };
  }

  it("rejects when no user exists for the email", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const { service } = makeService({ user });

    await expect(service.login({ email: "a@x.com", password: "pw" })).rejects.toThrow(
      "Invalid email or password"
    );
  });

  it("rejects while the account is locked, reporting minutes remaining", async () => {
    const lockedUntil = new Date(Date.now() + 5 * 60_000);
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue(baseUser({ lockedUntil })) });
    const { service } = makeService({ user });

    await expect(service.login({ email: "a@x.com", password: "pw" })).rejects.toMatchObject({
      statusCode: 423,
    });
  });

  it("rejects a Google-only account (no password set)", async () => {
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue(baseUser({ passwordHash: null })),
    });
    const { service } = makeService({ user });

    await expect(service.login({ email: "a@x.com", password: "pw" })).rejects.toThrow(
      "Google Sign-In"
    );
  });

  it("rejects an incorrect password and increments failedLoginAttempts", async () => {
    mockedCompare.mockResolvedValue(false);
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue(baseUser({ failedLoginAttempts: 1 })),
      update: jest.fn().mockResolvedValue({}),
    });
    const { service } = makeService({ user });

    await expect(service.login({ email: "a@x.com", password: "wrong" })).rejects.toThrow(
      "Invalid email or password"
    );
    expect(user.update).toHaveBeenCalledWith({
      where: { id: "u1" },
      data: { failedLoginAttempts: 2 },
    });
  });

  it("locks the account after the 5th consecutive failed attempt", async () => {
    mockedCompare.mockResolvedValue(false);
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue(baseUser({ failedLoginAttempts: 4 })),
      update: jest.fn().mockResolvedValue({}),
    });
    const { service } = makeService({ user });

    await expect(service.login({ email: "a@x.com", password: "wrong" })).rejects.toMatchObject({
      statusCode: 423,
    });
    expect(user.update).toHaveBeenCalledWith({
      where: { id: "u1" },
      data: { failedLoginAttempts: 0, lockedUntil: expect.any(Date) },
    });
  });

  it("logs in successfully, resets failure counters, and rotates the refresh token", async () => {
    mockedCompare.mockResolvedValue(true);
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue(baseUser({ failedLoginAttempts: 2 })),
      update: jest.fn().mockResolvedValue({}),
    });
    const refreshToken = mockModel({
      deleteMany: jest.fn().mockResolvedValue({}),
      create: jest.fn().mockResolvedValue({}),
    });
    const { service, tokenUtil } = makeService({ user, refreshToken });

    const result = await service.login({ email: "a@x.com", password: "correct" });

    expect(user.update).toHaveBeenCalledWith({
      where: { id: "u1" },
      data: { failedLoginAttempts: 0, lockedUntil: null },
    });
    expect(refreshToken.deleteMany).toHaveBeenCalledWith({ where: { userId: "u1" } });
    expect(refreshToken.create).toHaveBeenCalled();
    expect(tokenUtil.generateTokenPair).toHaveBeenCalledWith({
      sub: "u1",
      email: "a@x.com",
      role: "STUDENT",
    });
    expect(result).toEqual({
      user: { id: "u1", name: "A", email: "a@x.com" },
      accessToken: "access-token",
      refreshToken: "refresh-token",
    });
  });
});

describe("AuthService.loginWithGoogle", () => {
  it("rejects when the Google payload has no verified email", async () => {
    mockOAuthInstance.verifyIdToken.mockResolvedValue({
      getPayload: () => ({ email: "a@x.com", email_verified: false }),
    });
    const { service } = makeService({ user: mockModel() });

    await expect(service.loginWithGoogle("id-token")).rejects.toThrow(
      "email is missing or unverified"
    );
  });

  it("logs in an existing user matched by googleId", async () => {
    mockOAuthInstance.verifyIdToken.mockResolvedValue({
      getPayload: () => ({ sub: "google-1", email: "a@x.com", email_verified: true, name: "A" }),
    });
    const user = mockModel({
      findUnique: jest
        .fn()
        .mockResolvedValue({ id: "u1", name: "A", email: "a@x.com", role: "STUDENT" }),
    });
    const refreshToken = mockModel({
      deleteMany: jest.fn().mockResolvedValue({}),
      create: jest.fn().mockResolvedValue({}),
    });
    const { service } = makeService({ user, refreshToken });

    const result = await service.loginWithGoogle("id-token");

    expect(user.findUnique).toHaveBeenCalledWith({ where: { googleId: "google-1" } });
    expect(user.create).not.toHaveBeenCalled();
    expect(result.accessToken).toBe("access-token");
  });

  it("links googleId onto an existing email-matched account", async () => {
    mockOAuthInstance.verifyIdToken.mockResolvedValue({
      getPayload: () => ({ sub: "google-1", email: "a@x.com", email_verified: true, name: "A" }),
    });
    const user = mockModel({
      findUnique: jest
        .fn()
        .mockResolvedValueOnce(null) // lookup by googleId
        .mockResolvedValueOnce({ id: "u1", email: "a@x.com" }), // lookup by email
      update: jest
        .fn()
        .mockResolvedValue({ id: "u1", name: "A", email: "a@x.com", role: "STUDENT" }),
    });
    const refreshToken = mockModel({
      deleteMany: jest.fn().mockResolvedValue({}),
      create: jest.fn().mockResolvedValue({}),
    });
    const { service } = makeService({ user, refreshToken });

    await service.loginWithGoogle("id-token");

    expect(user.update).toHaveBeenCalledWith({
      where: { id: "u1" },
      data: { googleId: "google-1" },
    });
  });

  it("creates a brand-new user when neither googleId nor email match an existing account", async () => {
    mockOAuthInstance.verifyIdToken.mockResolvedValue({
      getPayload: () => ({ sub: "google-1", email: "new@x.com", email_verified: true, name: null }),
    });
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValueOnce(null).mockResolvedValueOnce(null),
      create: jest
        .fn()
        .mockResolvedValue({ id: "u2", name: "new", email: "new@x.com", role: "STUDENT" }),
    });
    const refreshToken = mockModel({
      deleteMany: jest.fn().mockResolvedValue({}),
      create: jest.fn().mockResolvedValue({}),
    });
    const { service } = makeService({ user, refreshToken });

    await service.loginWithGoogle("id-token");

    expect(user.create).toHaveBeenCalledWith({
      data: { name: "new", email: "new@x.com", googleId: "google-1" },
    });
  });
});

describe("AuthService.refresh", () => {
  it("rejects an unknown refresh token", async () => {
    const refreshToken = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const { service } = makeService({ refreshToken });

    await expect(service.refresh("bad-token")).rejects.toThrow(
      "Invalid or expired refresh token"
    );
  });

  it("rejects an expired refresh token", async () => {
    const refreshToken = mockModel({
      findUnique: jest.fn().mockResolvedValue({
        id: "rt1",
        expiresAt: new Date(Date.now() - 1000),
        user: { id: "u1", email: "a@x.com", role: "STUDENT" },
      }),
    });
    const { service } = makeService({ refreshToken });

    await expect(service.refresh("expired")).rejects.toThrow("Invalid or expired refresh token");
  });

  it("rotates a valid refresh token", async () => {
    const refreshToken = mockModel({
      findUnique: jest.fn().mockResolvedValue({
        id: "rt1",
        expiresAt: new Date(Date.now() + 100_000),
        user: { id: "u1", email: "a@x.com", role: "STUDENT" },
      }),
      update: jest.fn().mockResolvedValue({}),
    });
    const { service } = makeService({ refreshToken });

    const result = await service.refresh("valid-token");

    expect(refreshToken.update).toHaveBeenCalledWith({
      where: { id: "rt1" },
      data: { token: "refresh-token", expiresAt: expect.any(Date) },
    });
    expect(result).toEqual({ accessToken: "access-token", refreshToken: "refresh-token" });
  });
});

describe("AuthService.logout", () => {
  it("deletes all refresh tokens for the caller", async () => {
    const refreshToken = mockModel({ deleteMany: jest.fn().mockResolvedValue({}) });
    const { service } = makeService({ refreshToken });

    await service.logout("u1");

    expect(refreshToken.deleteMany).toHaveBeenCalledWith({ where: { userId: "u1" } });
  });
});

describe("AuthService.forgotPassword", () => {
  it("returns the generic message without sending mail when no user matches", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const { service, mailService } = makeService({ user });

    const result = await service.forgotPassword("nobody@x.com");

    expect(result.message).toMatch(/If an account exists/);
    expect(mailService.sendPasswordResetCode).not.toHaveBeenCalled();
  });

  it("rejects a resend within the cooldown window", async () => {
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue({ id: "u1", email: "a@x.com", name: "A" }),
    });
    const passwordResetToken = mockModel({
      findFirst: jest.fn().mockResolvedValue({ createdAt: new Date() }),
    });
    const { service } = makeService({ user, passwordResetToken });

    await expect(service.forgotPassword("a@x.com")).rejects.toThrow(/wait a moment/);
  });

  it("creates a reset code and emails it when no cooldown applies", async () => {
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue({ id: "u1", email: "a@x.com", name: "A" }),
    });
    const passwordResetToken = mockModel({
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({}),
    });
    const { service, mailService } = makeService({ user, passwordResetToken });

    const result = await service.forgotPassword("a@x.com");

    expect(passwordResetToken.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ userId: "u1", codeHash: "hashed:123456" }) })
    );
    expect(mailService.sendPasswordResetCode).toHaveBeenCalledWith("a@x.com", "A", "123456");
    expect(result.message).toMatch(/If an account exists/);
  });
});

describe("AuthService.verifyResetCode", () => {
  it("rejects when no user matches the email", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const { service } = makeService({ user });

    await expect(service.verifyResetCode("nobody@x.com", "123456")).rejects.toThrow(AppError);
  });

  it("rejects and increments attempts on an incorrect code", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "u1" }) });
    const passwordResetToken = mockModel({
      findFirst: jest.fn().mockResolvedValue({
        id: "t1",
        expiresAt: new Date(Date.now() + 100_000),
        attempts: 0,
        codeHash: "hashed:999999",
      }),
      update: jest.fn().mockResolvedValue({}),
    });
    const { service } = makeService({ user, passwordResetToken });

    await expect(service.verifyResetCode("a@x.com", "123456")).rejects.toThrow(
      /Invalid or expired reset code/
    );
    expect(passwordResetToken.update).toHaveBeenCalledWith({
      where: { id: "t1" },
      data: { attempts: { increment: 1 } },
    });
  });

  it("rejects once the max incorrect-attempt count is reached", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "u1" }) });
    const passwordResetToken = mockModel({
      findFirst: jest.fn().mockResolvedValue({
        id: "t1",
        expiresAt: new Date(Date.now() + 100_000),
        attempts: 5,
        codeHash: "hashed:123456",
      }),
    });
    const { service } = makeService({ user, passwordResetToken });

    await expect(service.verifyResetCode("a@x.com", "123456")).rejects.toThrow(
      /Too many incorrect attempts/
    );
  });

  it("rejects an expired token", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "u1" }) });
    const passwordResetToken = mockModel({
      findFirst: jest.fn().mockResolvedValue({
        id: "t1",
        expiresAt: new Date(Date.now() - 1000),
        attempts: 0,
        codeHash: "hashed:123456",
      }),
    });
    const { service } = makeService({ user, passwordResetToken });

    await expect(service.verifyResetCode("a@x.com", "123456")).rejects.toThrow(
      /Invalid or expired reset code/
    );
  });

  it("returns a reset session token for a correct code", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "u1" }) });
    const passwordResetToken = mockModel({
      findFirst: jest.fn().mockResolvedValue({
        id: "t1",
        expiresAt: new Date(Date.now() + 100_000),
        attempts: 0,
        codeHash: "hashed:123456",
      }),
      update: jest.fn().mockResolvedValue({}),
    });
    const { service } = makeService({ user, passwordResetToken });

    const result = await service.verifyResetCode("a@x.com", "123456");

    expect(result).toEqual({ resetToken: "reset-session-token" });
    expect(passwordResetToken.update).toHaveBeenCalledWith({
      where: { id: "t1" },
      data: {
        verifiedAt: expect.any(Date),
        resetTokenHash: "hashed:reset-session-token",
        expiresAt: expect.any(Date),
      },
    });
  });
});

describe("AuthService.resetPassword", () => {
  it("rejects when no verified, unused, unexpired token matches", async () => {
    const passwordResetToken = mockModel({ findFirst: jest.fn().mockResolvedValue(null) });
    const { service } = makeService({ passwordResetToken });

    await expect(service.resetPassword("bad-session-token", "newpassword1")).rejects.toThrow(
      /reset session has expired/
    );
  });

  it("updates the password, marks the token used, and revokes all sessions", async () => {
    mockedHash.mockResolvedValue("new-hashed-pw");
    const passwordResetToken = mockModel({
      findFirst: jest.fn().mockResolvedValue({ id: "t1", userId: "u1" }),
      update: jest.fn().mockResolvedValue({}),
    });
    const user = mockModel({ update: jest.fn().mockResolvedValue({}) });
    const refreshToken = mockModel({ deleteMany: jest.fn().mockResolvedValue({}) });
    const { service } = makeService({ passwordResetToken, user, refreshToken });

    await service.resetPassword("good-session-token", "newpassword1");

    expect(user.update).toHaveBeenCalledWith({
      where: { id: "u1" },
      data: { passwordHash: "new-hashed-pw", failedLoginAttempts: 0, lockedUntil: null },
    });
    expect(passwordResetToken.update).toHaveBeenCalledWith({
      where: { id: "t1" },
      data: { usedAt: expect.any(Date) },
    });
    expect(refreshToken.deleteMany).toHaveBeenCalledWith({ where: { userId: "u1" } });
  });
});
