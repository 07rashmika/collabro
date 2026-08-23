import request from "supertest";
import bcrypt from "bcrypt";
import { mockModel } from "../../test-helpers/mock-prisma";

// The whole app is exercised through real HTTP requests (supertest → Express
// → router → controller → service → Zod validation), with only the Prisma
// boundary swapped for an in-memory mock — everything else in the request
// pipeline (jwtGuard, zod schemas, error filters) runs for real.
jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    user: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    refreshToken: { create: jest.fn(), deleteMany: jest.fn() },
    profile: { findUnique: jest.fn() },
    connection: { findMany: jest.fn() },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  user: ReturnType<typeof mockModel>;
  refreshToken: ReturnType<typeof mockModel>;
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string, email: string, role = "STUDENT") {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email, role }).accessToken}`;
}

describe("GET /", () => {
  it("responds with a health check", async () => {
    const res = await request(app).get("/");
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: "ok", service: "collabro-api" });
  });
});

describe("jwtGuard", () => {
  afterEach(() => jest.clearAllMocks());

  it("rejects a request with no Authorization header", async () => {
    const res = await request(app).get("/users/me");
    expect(res.status).toBe(401);
  });

  it("rejects a malformed Authorization header", async () => {
    const res = await request(app).get("/users/me").set("Authorization", "Token abc123");
    expect(res.status).toBe(401);
  });

  it("rejects a garbage/expired access token", async () => {
    const res = await request(app).get("/users/me").set("Authorization", "Bearer not-a-real-jwt");
    expect(res.status).toBe(401);
  });
});

describe("GET /users/me", () => {
  afterEach(() => jest.clearAllMocks());

  it("returns the caller's profile for a valid access token", async () => {
    (client.user.findUnique as jest.Mock).mockResolvedValue({
      id: "user-1",
      name: "Rashmika",
      email: "rashmika@bedfordshire.ac.uk",
      role: "STUDENT",
      avatarUrl: null,
      notifyMessages: true,
      notifyConnections: true,
      notifyVideoSessions: true,
      createdAt: new Date().toISOString(),
      profile: null,
      _count: { notes: 0, createdSessions: 0 },
    });

    const res = await request(app)
      .get("/users/me")
      .set("Authorization", bearerFor("user-1", "rashmika@bedfordshire.ac.uk"));

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ id: "user-1", email: "rashmika@bedfordshire.ac.uk" });
  });

  it("404s when the token is valid but the user no longer exists", async () => {
    (client.user.findUnique as jest.Mock).mockResolvedValue(null);

    const res = await request(app)
      .get("/users/me")
      .set("Authorization", bearerFor("deleted-user", "gone@bedfordshire.ac.uk"));

    expect(res.status).toBe(404);
  });
});

describe("PATCH /users/me", () => {
  afterEach(() => jest.clearAllMocks());

  it("rejects an invalid body with a 400 and field-level Zod errors", async () => {
    (client.user.findUnique as jest.Mock).mockResolvedValue({ id: "user-1" });

    const res = await request(app)
      .patch("/users/me")
      .set("Authorization", bearerFor("user-1", "rashmika@bedfordshire.ac.uk"))
      .send({ name: "a" }); // below the 2-char minimum in UpdateUserSchema

    expect(res.status).toBe(400);
    expect(res.body.message).toBe("Validation failed");
  });

  it("updates notification preferences end-to-end", async () => {
    (client.user.findUnique as jest.Mock).mockResolvedValue({ id: "user-1" });
    (client.user.update as jest.Mock).mockResolvedValue({
      id: "user-1",
      notifyMessages: false,
      notifyConnections: true,
      notifyVideoSessions: true,
    });

    const res = await request(app)
      .patch("/users/me")
      .set("Authorization", bearerFor("user-1", "rashmika@bedfordshire.ac.uk"))
      .send({ notifyMessages: false });

    expect(res.status).toBe(200);
    expect(client.user.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: "user-1" }, data: { notifyMessages: false } })
    );
    expect(res.body.notifyMessages).toBe(false);
  });
});

describe("POST /auth/register", () => {
  afterEach(() => jest.clearAllMocks());

  it("rejects a password shorter than 8 characters", async () => {
    const res = await request(app)
      .post("/auth/register")
      .send({ name: "Jane Doe", email: "jane@bedfordshire.ac.uk", password: "short" });

    expect(res.status).toBe(400);
  });

  it("rejects registering an email that's already taken", async () => {
    (client.user.findUnique as jest.Mock).mockResolvedValue({ id: "existing-user" });

    const res = await request(app)
      .post("/auth/register")
      .send({ name: "Jane Doe", email: "jane@bedfordshire.ac.uk", password: "password123" });

    expect(res.status).toBe(409);
  });

  it("registers a new user and returns a token pair", async () => {
    (client.user.findUnique as jest.Mock).mockResolvedValue(null);
    (client.user.create as jest.Mock).mockResolvedValue({
      id: "new-user",
      name: "Jane Doe",
      email: "jane@bedfordshire.ac.uk",
      role: "STUDENT",
      createdAt: new Date(),
    });
    (client.refreshToken.create as jest.Mock).mockResolvedValue({});

    const res = await request(app)
      .post("/auth/register")
      .send({ name: "Jane Doe", email: "jane@bedfordshire.ac.uk", password: "password123" });

    expect(res.status).toBe(201);
    expect(res.body.accessToken).toEqual(expect.any(String));
    expect(res.body.user.email).toBe("jane@bedfordshire.ac.uk");
  });
});

describe("POST /auth/login", () => {
  afterEach(() => jest.clearAllMocks());

  it("rejects an incorrect password with 401", async () => {
    (client.user.findUnique as jest.Mock).mockResolvedValue({
      id: "user-1",
      name: "Jane",
      email: "jane@bedfordshire.ac.uk",
      role: "STUDENT",
      passwordHash: bcrypt.hashSync("correct-password", 4),
      failedLoginAttempts: 0,
      lockedUntil: null,
    });

    const res = await request(app)
      .post("/auth/login")
      .send({ email: "jane@bedfordshire.ac.uk", password: "wrong-password" });

    expect(res.status).toBe(401);
  });

  it("logs in successfully with the correct password", async () => {
    (client.user.findUnique as jest.Mock).mockResolvedValue({
      id: "user-1",
      name: "Jane",
      email: "jane@bedfordshire.ac.uk",
      role: "STUDENT",
      passwordHash: bcrypt.hashSync("correct-password", 4),
      failedLoginAttempts: 0,
      lockedUntil: null,
    });
    (client.user.update as jest.Mock).mockResolvedValue({});
    (client.refreshToken.create as jest.Mock).mockResolvedValue({});

    const res = await request(app)
      .post("/auth/login")
      .send({ email: "jane@bedfordshire.ac.uk", password: "correct-password" });

    expect(res.status).toBe(200);
    expect(res.body.accessToken).toEqual(expect.any(String));
  });
});
