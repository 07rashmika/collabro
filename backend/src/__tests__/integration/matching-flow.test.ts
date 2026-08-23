import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    profile: { findUnique: jest.fn(), findMany: jest.fn() },
    connection: { findMany: jest.fn() },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  profile: { findUnique: jest.Mock; findMany: jest.Mock };
  connection: { findMany: jest.Mock };
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string) {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email: `${sub}@bedfordshire.ac.uk`, role: "STUDENT" }).accessToken}`;
}

function buildProfile(overrides: Record<string, unknown> = {}) {
  return {
    userId: "caller-1",
    bio: null,
    learningGoal: null,
    teachGoal: null,
    interests: [] as string[],
    user: { id: "caller-1", name: "Caller", email: "caller@bedfordshire.ac.uk", avatarUrl: null },
    skills: [] as unknown[],
    studyAreas: [] as unknown[],
    ...overrides,
  };
}

beforeEach(() => {
  client.connection.findMany.mockResolvedValue([]);
});

afterEach(() => jest.clearAllMocks());

describe("GET /matching/suggestions", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).get("/matching/suggestions");
    expect(res.status).toBe(401);
  });

  it("responds with 400 when the caller has no profile set up", async () => {
    client.profile.findUnique.mockResolvedValue(null);

    const res = await request(app)
      .get("/matching/suggestions")
      .set("Authorization", bearerFor("caller-1"));

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/set up your profile/);
  });

  it("returns ranked suggestions for a caller with a profile", async () => {
    client.profile.findUnique.mockResolvedValue(
      buildProfile({
        skills: [{ level: "BEGINNER", skill: { id: "s1", name: "React", category: "Frontend" } }],
      })
    );
    client.profile.findMany.mockResolvedValue([]);

    const res = await request(app)
      .get("/matching/suggestions")
      .set("Authorization", bearerFor("caller-1"));

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ suggestions: [], total: 0 });
  });
});

describe("GET /matching/score/:userId", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).get("/matching/score/user-2");
    expect(res.status).toBe(401);
  });

  it("responds with 404 when the target student has no profile", async () => {
    client.profile.findUnique.mockImplementation(({ where }: { where: { userId: string } }) =>
      where.userId === "caller-1" ? Promise.resolve(buildProfile()) : Promise.resolve(null)
    );

    const res = await request(app)
      .get("/matching/score/user-2")
      .set("Authorization", bearerFor("caller-1"));

    expect(res.status).toBe(404);
  });

  it("returns a compatibility score between the caller and the target student", async () => {
    client.profile.findUnique.mockImplementation(({ where }: { where: { userId: string } }) =>
      Promise.resolve(
        buildProfile({
          userId: where.userId,
          skills: [{ level: "BEGINNER", skill: { id: "s1", name: "React", category: "Frontend" } }],
        })
      )
    );

    const res = await request(app)
      .get("/matching/score/user-2")
      .set("Authorization", bearerFor("caller-1"));

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty("totalScore");
    expect(res.body).toHaveProperty("aiReason");
  });
});
