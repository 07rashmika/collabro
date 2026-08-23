import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    session: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    savedSession: { findMany: jest.fn() },
    user: { findMany: jest.fn() },
    skill: { findMany: jest.fn() },
    notification: { create: jest.fn() },
    deviceToken: { findMany: jest.fn().mockResolvedValue([]) },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  session: {
    findUnique: jest.Mock;
    findMany: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
    count: jest.Mock;
  };
  savedSession: { findMany: jest.Mock };
  user: { findMany: jest.Mock };
  skill: { findMany: jest.Mock };
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string) {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email: `${sub}@bedfordshire.ac.uk`, role: "STUDENT" }).accessToken}`;
}

function buildSession(overrides: Record<string, unknown> = {}) {
  return {
    id: "session-1",
    title: "Study group",
    type: "TEXT",
    status: "ACTIVE",
    summary: null,
    transcript: null,
    scheduledAt: null,
    joinCode: "ABC123",
    encryptedPassword: null,
    isPublic: false,
    createdBy: "creator-1",
    createdAt: new Date("2026-01-01T00:00:00Z"),
    updatedAt: new Date("2026-01-01T00:00:00Z"),
    creator: { id: "creator-1", name: "Creator", email: "creator@bedfordshire.ac.uk", avatarUrl: null },
    participants: [
      { userId: "creator-1", joinedAt: new Date(), user: { id: "creator-1", name: "Creator", email: "creator@bedfordshire.ac.uk", avatarUrl: null } },
    ],
    tags: [] as unknown[],
    _count: { messages: 0 },
    ...overrides,
  };
}

beforeEach(() => {
  client.savedSession.findMany.mockResolvedValue([]);
});

afterEach(() => jest.clearAllMocks());

describe("POST /sessions", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).post("/sessions").send({ title: "Study group" });
    expect(res.status).toBe(401);
  });

  it("rejects a body with no title with a 400", async () => {
    const res = await request(app)
      .post("/sessions")
      .set("Authorization", bearerFor("creator-1"))
      .send({});

    expect(res.status).toBe(400);
  });

  it("creates a session and returns it", async () => {
    client.user.findMany.mockResolvedValue([]);
    client.skill.findMany.mockResolvedValue([]);
    client.session.create.mockResolvedValue(buildSession());

    const res = await request(app)
      .post("/sessions")
      .set("Authorization", bearerFor("creator-1"))
      .send({ title: "Study group" });

    expect(res.status).toBe(201);
    expect(res.body.title).toBe("Study group");
    expect(res.body.hasPassword).toBe(false);
  });
});

describe("GET /sessions/:id", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).get("/sessions/session-1");
    expect(res.status).toBe(401);
  });

  it("responds with 404 when the session doesn't exist", async () => {
    client.session.findUnique.mockResolvedValue(null);

    const res = await request(app)
      .get("/sessions/session-1")
      .set("Authorization", bearerFor("creator-1"));

    expect(res.status).toBe(404);
  });

  it("responds with 403 when the caller isn't a participant", async () => {
    client.session.findUnique.mockResolvedValue(buildSession());

    const res = await request(app)
      .get("/sessions/session-1")
      .set("Authorization", bearerFor("outsider-1"));

    expect(res.status).toBe(403);
  });

  it("returns the session for a participant", async () => {
    client.session.findUnique.mockResolvedValue(buildSession());

    const res = await request(app)
      .get("/sessions/session-1")
      .set("Authorization", bearerFor("creator-1"));

    expect(res.status).toBe(200);
    expect(res.body.id).toBe("session-1");
    expect(res.body.savedByMe).toBe(false);
  });
});

describe("PATCH /sessions/:id/close", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).patch("/sessions/session-1/close");
    expect(res.status).toBe(401);
  });

  it("responds with 403 when the caller isn't the session creator", async () => {
    client.session.findUnique.mockResolvedValue(buildSession());

    const res = await request(app)
      .patch("/sessions/session-1/close")
      .set("Authorization", bearerFor("not-the-creator"));

    expect(res.status).toBe(403);
  });

  it("closes the session when the caller is the creator", async () => {
    client.session.findUnique.mockResolvedValue(buildSession());
    client.session.update.mockResolvedValue(buildSession({ status: "CLOSED" }));

    const res = await request(app)
      .patch("/sessions/session-1/close")
      .set("Authorization", bearerFor("creator-1"));

    expect(res.status).toBe(200);
    expect(res.body.status).toBe("CLOSED");
  });
});
