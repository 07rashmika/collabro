import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    profile: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  profile: {
    findUnique: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
  };
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string) {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email: `${sub}@bedfordshire.ac.uk`, role: "STUDENT" }).accessToken}`;
}

afterEach(() => jest.clearAllMocks());

describe("GET /profiles/me", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).get("/profiles/me");
    expect(res.status).toBe(401);
  });

  it("404s when the caller has no profile yet", async () => {
    client.profile.findUnique.mockResolvedValue(null);

    const res = await request(app)
      .get("/profiles/me")
      .set("Authorization", bearerFor("user-1"));

    expect(res.status).toBe(404);
  });

  it("returns the caller's profile", async () => {
    client.profile.findUnique.mockResolvedValue({
      id: "profile-1",
      bio: null,
      user: { id: "user-1", name: "User" },
      skills: [],
      studyAreas: [],
    });

    const res = await request(app)
      .get("/profiles/me")
      .set("Authorization", bearerFor("user-1"));

    expect(res.status).toBe(200);
    expect(res.body.id).toBe("profile-1");
  });
});

describe("POST /profiles", () => {
  it("rejects an invalid body with a 400", async () => {
    const res = await request(app)
      .post("/profiles")
      .set("Authorization", bearerFor("user-1"))
      .send({ interests: "not-an-array" });

    expect(res.status).toBe(400);
  });

  it("rejects creating a duplicate profile with a 409", async () => {
    client.profile.findUnique.mockResolvedValue({ id: "profile-1" });

    const res = await request(app)
      .post("/profiles")
      .set("Authorization", bearerFor("user-1"))
      .send({ bio: "hi" });

    expect(res.status).toBe(409);
  });

  it("creates a profile for the caller", async () => {
    client.profile.findUnique.mockResolvedValue(null);
    client.profile.create.mockResolvedValue({
      id: "profile-1",
      bio: "hi",
      user: { id: "user-1", name: "User" },
      skills: [],
      studyAreas: [],
    });

    const res = await request(app)
      .post("/profiles")
      .set("Authorization", bearerFor("user-1"))
      .send({ bio: "hi" });

    expect(res.status).toBe(201);
    expect(res.body.bio).toBe("hi");
  });
});
