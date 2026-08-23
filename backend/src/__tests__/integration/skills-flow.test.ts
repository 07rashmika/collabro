import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    skill: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      createMany: jest.fn(),
    },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  skill: {
    findMany: jest.Mock;
    findUnique: jest.Mock;
    findFirst: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
    createMany: jest.Mock;
  };
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string, role: "STUDENT" | "ADMIN" = "STUDENT") {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email: `${sub}@bedfordshire.ac.uk`, role }).accessToken}`;
}

afterEach(() => jest.clearAllMocks());

describe("GET /skills", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).get("/skills");
    expect(res.status).toBe(401);
  });

  it("returns the skill catalog for an authenticated student", async () => {
    client.skill.findMany.mockResolvedValue([{ id: "s1", name: "React", category: "Frontend" }]);

    const res = await request(app).get("/skills").set("Authorization", bearerFor("user-1"));

    expect(res.status).toBe(200);
    expect(res.body).toEqual([{ id: "s1", name: "React", category: "Frontend" }]);
  });
});

describe("POST /skills", () => {
  it("rejects a non-admin caller with a 403", async () => {
    const res = await request(app)
      .post("/skills")
      .set("Authorization", bearerFor("user-1", "STUDENT"))
      .send({ name: "Rust", category: "Backend" });

    expect(res.status).toBe(403);
    expect(client.skill.create).not.toHaveBeenCalled();
  });

  it("creates a skill for an admin caller", async () => {
    client.skill.findUnique.mockResolvedValue(null);
    client.skill.create.mockResolvedValue({ id: "s1", name: "Rust", category: "Backend" });

    const res = await request(app)
      .post("/skills")
      .set("Authorization", bearerFor("admin-1", "ADMIN"))
      .send({ name: "Rust", category: "Backend" });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ id: "s1", name: "Rust", category: "Backend" });
  });
});
