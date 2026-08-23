import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    note: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      count: jest.fn(),
    },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  note: {
    findUnique: jest.Mock;
    findMany: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
    delete: jest.Mock;
    count: jest.Mock;
  };
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string) {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email: `${sub}@bedfordshire.ac.uk`, role: "STUDENT" }).accessToken}`;
}

afterEach(() => jest.clearAllMocks());

describe("GET /notes/me", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).get("/notes/me");
    expect(res.status).toBe(401);
  });
});

describe("notes CRUD round trip", () => {
  it("creates, fetches, updates, and deletes a note", async () => {
    const now = new Date().toISOString();
    const created = {
      id: "note-1",
      authorId: "user-1",
      title: "React basics",
      content: "Hooks, props, state",
      summary: null,
      tags: ["react"],
      isPublic: false,
      createdAt: now,
      updatedAt: now,
      author: { id: "user-1", name: "User", email: "user-1@bedfordshire.ac.uk", avatarUrl: null },
      photos: [],
    };
    client.note.create.mockResolvedValue(created);

    const createRes = await request(app)
      .post("/notes")
      .set("Authorization", bearerFor("user-1"))
      .send({ title: "React basics", content: "Hooks, props, state", tags: ["react"] });

    expect(createRes.status).toBe(201);
    expect(createRes.body.id).toBe("note-1");

    client.note.findUnique.mockResolvedValue(created);

    const getRes = await request(app)
      .get("/notes/note-1")
      .set("Authorization", bearerFor("user-1"));

    expect(getRes.status).toBe(200);
    expect(getRes.body.title).toBe("React basics");

    client.note.update.mockResolvedValue({ ...created, title: "Updated title" });

    const updateRes = await request(app)
      .patch("/notes/note-1")
      .set("Authorization", bearerFor("user-1"))
      .send({ title: "Updated title" });

    expect(updateRes.status).toBe(200);
    expect(updateRes.body.title).toBe("Updated title");

    client.note.delete.mockResolvedValue(undefined);

    const deleteRes = await request(app)
      .delete("/notes/note-1")
      .set("Authorization", bearerFor("user-1"));

    expect(deleteRes.status).toBe(204);
  });

  it("rejects updating someone else's note with a 403", async () => {
    client.note.findUnique.mockResolvedValue({
      id: "note-1",
      authorId: "user-1",
    });

    const res = await request(app)
      .patch("/notes/note-1")
      .set("Authorization", bearerFor("user-2"))
      .send({ title: "Hijacked" });

    expect(res.status).toBe(403);
  });
});
