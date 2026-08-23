import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    studyArea: {
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
  studyArea: {
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

describe("GET /study-areas", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).get("/study-areas");
    expect(res.status).toBe(401);
  });

  it("returns the study-area catalog for an authenticated student", async () => {
    client.studyArea.findMany.mockResolvedValue([{ id: "a1", name: "Computer Science" }]);

    const res = await request(app).get("/study-areas").set("Authorization", bearerFor("user-1"));

    expect(res.status).toBe(200);
    expect(res.body).toEqual([{ id: "a1", name: "Computer Science" }]);
  });
});

describe("POST /study-areas", () => {
  it("rejects a non-admin caller with a 403", async () => {
    const res = await request(app)
      .post("/study-areas")
      .set("Authorization", bearerFor("user-1", "STUDENT"))
      .send({ name: "Physics" });

    expect(res.status).toBe(403);
    expect(client.studyArea.create).not.toHaveBeenCalled();
  });

  it("creates a study area for an admin caller", async () => {
    client.studyArea.findUnique.mockResolvedValue(null);
    client.studyArea.create.mockResolvedValue({ id: "a1", name: "Physics" });

    const res = await request(app)
      .post("/study-areas")
      .set("Authorization", bearerFor("admin-1", "ADMIN"))
      .send({ name: "Physics" });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ id: "a1", name: "Physics" });
  });
});
