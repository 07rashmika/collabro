import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    session: { findUnique: jest.fn() },
    report: { create: jest.fn() },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  session: { findUnique: jest.Mock };
  report: { create: jest.Mock };
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string) {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email: `${sub}@bedfordshire.ac.uk`, role: "STUDENT" }).accessToken}`;
}

function buildSession(overrides: Record<string, unknown> = {}) {
  return {
    id: "session-1",
    createdBy: "creator-1",
    participants: [{ userId: "creator-1" }, { userId: "user-2" }],
    ...overrides,
  };
}

afterEach(() => jest.clearAllMocks());

describe("POST /sessions/:id/reports", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app)
      .post("/sessions/session-1/reports")
      .send({ targetType: "SESSION", reason: "OTHER" });

    expect(res.status).toBe(401);
  });

  it("rejects an invalid reason with a 400 validation error", async () => {
    const res = await request(app)
      .post("/sessions/session-1/reports")
      .set("Authorization", bearerFor("creator-1"))
      .send({ targetType: "SESSION", reason: "NOT_A_REAL_REASON" });

    expect(res.status).toBe(400);
  });

  it("rejects a USER report with no reportedUserId with a 400 validation error", async () => {
    const res = await request(app)
      .post("/sessions/session-1/reports")
      .set("Authorization", bearerFor("creator-1"))
      .send({ targetType: "USER", reason: "OTHER" });

    expect(res.status).toBe(400);
  });

  it("responds with 404 when the session doesn't exist", async () => {
    client.session.findUnique.mockResolvedValue(null);

    const res = await request(app)
      .post("/sessions/session-1/reports")
      .set("Authorization", bearerFor("creator-1"))
      .send({ targetType: "SESSION", reason: "OTHER" });

    expect(res.status).toBe(404);
  });

  it("responds with 403 when the caller isn't part of the session", async () => {
    client.session.findUnique.mockResolvedValue(buildSession());

    const res = await request(app)
      .post("/sessions/session-1/reports")
      .set("Authorization", bearerFor("outsider-1"))
      .send({ targetType: "SESSION", reason: "OTHER" });

    expect(res.status).toBe(403);
  });

  it("responds with 400 when a USER report targets someone outside the session", async () => {
    client.session.findUnique.mockResolvedValue(buildSession());

    const res = await request(app)
      .post("/sessions/session-1/reports")
      .set("Authorization", bearerFor("creator-1"))
      .send({ targetType: "USER", reportedUserId: "not-in-session", reason: "OTHER" });

    expect(res.status).toBe(400);
  });

  it("creates a SESSION report from a participant and returns 201", async () => {
    client.session.findUnique.mockResolvedValue(buildSession());
    client.report.create.mockImplementation(({ data }) =>
      Promise.resolve({ id: "report-1", status: "PENDING", ...data })
    );

    const res = await request(app)
      .post("/sessions/session-1/reports")
      .set("Authorization", bearerFor("creator-1"))
      .send({ targetType: "SESSION", reason: "SPAM_OR_ADVERTISING", details: "too many ads" });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe("PENDING");
    expect(client.report.create).toHaveBeenCalledWith({
      data: {
        targetType: "SESSION",
        reporterId: "creator-1",
        sessionId: "session-1",
        reportedUserId: null,
        reason: "SPAM_OR_ADVERTISING",
        details: "too many ads",
      },
    });
  });

  it("creates a USER report against a fellow participant and returns 201", async () => {
    client.session.findUnique.mockResolvedValue(buildSession());
    client.report.create.mockImplementation(({ data }) =>
      Promise.resolve({ id: "report-1", status: "PENDING", ...data })
    );

    const res = await request(app)
      .post("/sessions/session-1/reports")
      .set("Authorization", bearerFor("creator-1"))
      .send({ targetType: "USER", reportedUserId: "user-2", reason: "HARASSMENT_OR_BULLYING" });

    expect(res.status).toBe(201);
    expect(res.body.reportedUserId).toBe("user-2");
  });
});
