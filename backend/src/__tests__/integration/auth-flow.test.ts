import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    refreshToken: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      deleteMany: jest.fn(),
    },
    passwordResetToken: {
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

const verifyIdToken = jest.fn();
jest.mock("google-auth-library", () => ({
  OAuth2Client: jest.fn().mockImplementation(() => ({ verifyIdToken })),
}));

const sendMail = jest.fn();
jest.mock("nodemailer", () => ({
  createTransport: jest.fn(() => ({ sendMail })),
}));

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  user: { findUnique: jest.Mock; create: jest.Mock; update: jest.Mock };
  refreshToken: {
    findUnique: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
    deleteMany: jest.Mock;
  };
  passwordResetToken: { findFirst: jest.Mock; create: jest.Mock; update: jest.Mock };
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string) {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email: `${sub}@bedfordshire.ac.uk`, role: "STUDENT" }).accessToken}`;
}

beforeEach(() => {
  process.env.SMTP_HOST = "smtp.example.com";
  process.env.SMTP_PORT = "587";
  process.env.SMTP_USER = "user@example.com";
  process.env.SMTP_PASS = "secret";
  sendMail.mockResolvedValue({});
});

afterEach(() => jest.clearAllMocks());

describe("POST /auth/refresh", () => {
  it("rejects an unknown refresh token with 401", async () => {
    client.refreshToken.findUnique.mockResolvedValue(null);

    const res = await request(app).post("/auth/refresh").send({ refreshToken: "bad-token" });

    expect(res.status).toBe(401);
  });

  it("issues a new token pair for a valid refresh token", async () => {
    client.refreshToken.findUnique.mockResolvedValue({
      id: "rt1",
      expiresAt: new Date(Date.now() + 100_000),
      user: { id: "u1", email: "a@bedfordshire.ac.uk", role: "STUDENT" },
    });
    client.refreshToken.update.mockResolvedValue({});

    const res = await request(app).post("/auth/refresh").send({ refreshToken: "good-token" });

    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
  });
});

describe("POST /auth/logout", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).post("/auth/logout");
    expect(res.status).toBe(401);
  });

  it("clears the caller's refresh tokens and returns 204", async () => {
    client.refreshToken.deleteMany.mockResolvedValue({});

    const res = await request(app)
      .post("/auth/logout")
      .set("Authorization", bearerFor("user-1"));

    expect(res.status).toBe(204);
    expect(client.refreshToken.deleteMany).toHaveBeenCalledWith({ where: { userId: "user-1" } });
  });
});

describe("POST /auth/google", () => {
  it("rejects a missing idToken with a 400 validation error", async () => {
    const res = await request(app).post("/auth/google").send({});
    expect(res.status).toBe(400);
  });

  it("logs in an existing Google user", async () => {
    verifyIdToken.mockResolvedValue({
      getPayload: () => ({
        sub: "google-1",
        email: "a@bedfordshire.ac.uk",
        email_verified: true,
        name: "A",
      }),
    });
    client.user.findUnique.mockResolvedValue({
      id: "u1",
      name: "A",
      email: "a@bedfordshire.ac.uk",
      role: "STUDENT",
    });
    client.refreshToken.deleteMany.mockResolvedValue({});
    client.refreshToken.create.mockResolvedValue({});

    const res = await request(app).post("/auth/google").send({ idToken: "google-id-token" });

    expect(res.status).toBe(200);
    expect(res.body.accessToken).toBeDefined();
  });
});

describe("POST /auth/forgot-password", () => {
  it("rejects an invalid email with 400", async () => {
    const res = await request(app)
      .post("/auth/forgot-password")
      .send({ email: "not-an-email" });

    expect(res.status).toBe(400);
  });

  it("responds with the generic message and sends mail when the user exists", async () => {
    client.user.findUnique.mockResolvedValue({
      id: "u1",
      email: "a@bedfordshire.ac.uk",
      name: "A",
    });
    client.passwordResetToken.findFirst.mockResolvedValue(null);
    client.passwordResetToken.create.mockResolvedValue({});

    const res = await request(app)
      .post("/auth/forgot-password")
      .send({ email: "a@bedfordshire.ac.uk" });

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/If an account exists/);
    expect(sendMail).toHaveBeenCalled();
  });
});

describe("POST /auth/verify-reset-code", () => {
  it("rejects a malformed code with 400", async () => {
    const res = await request(app)
      .post("/auth/verify-reset-code")
      .send({ email: "a@bedfordshire.ac.uk", code: "12" });

    expect(res.status).toBe(400);
  });

  it("rejects an incorrect code with 400", async () => {
    client.user.findUnique.mockResolvedValue({ id: "u1" });
    client.passwordResetToken.findFirst.mockResolvedValue({
      id: "t1",
      expiresAt: new Date(Date.now() + 100_000),
      attempts: 0,
      codeHash: "does-not-match",
    });
    client.passwordResetToken.update.mockResolvedValue({});

    const res = await request(app)
      .post("/auth/verify-reset-code")
      .send({ email: "a@bedfordshire.ac.uk", code: "123456" });

    expect(res.status).toBe(400);
  });
});

describe("POST /auth/reset-password", () => {
  it("rejects an expired/unknown reset session with 400", async () => {
    client.passwordResetToken.findFirst.mockResolvedValue(null);

    const res = await request(app)
      .post("/auth/reset-password")
      .send({ resetToken: "bad-session-token", newPassword: "newpassword1" });

    expect(res.status).toBe(400);
  });

  it(
    "resets the password for a valid session token",
    async () => {
      client.passwordResetToken.findFirst.mockResolvedValue({ id: "t1", userId: "u1" });
      client.passwordResetToken.update.mockResolvedValue({});
      client.user.update.mockResolvedValue({});
      client.refreshToken.deleteMany.mockResolvedValue({});

      const res = await request(app)
        .post("/auth/reset-password")
        .send({ resetToken: "good-session-token", newPassword: "newpassword1" });

      expect(res.status).toBe(200);
    },
    10_000
  );
});
