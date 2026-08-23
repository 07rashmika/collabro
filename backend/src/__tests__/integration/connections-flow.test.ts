import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    user: { findUnique: jest.fn() },
    connection: {
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    notification: {
      create: jest.fn(),
      deleteMany: jest.fn(),
      updateMany: jest.fn(),
    },
    deviceToken: { findMany: jest.fn().mockResolvedValue([]) },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  user: { findUnique: jest.Mock };
  connection: {
    findFirst: jest.Mock;
    findUnique: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
  };
  notification: { create: jest.Mock };
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string) {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email: `${sub}@bedfordshire.ac.uk`, role: "STUDENT" }).accessToken}`;
}

beforeEach(() => {
  client.user.findUnique.mockResolvedValue({ id: "user-2", name: "Jane" });
  client.connection.findFirst.mockResolvedValue(null);
  client.notification.create.mockResolvedValue({});
});

afterEach(() => jest.clearAllMocks());

describe("POST /connections", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).post("/connections").send({ addresseeId: "user-2" });
    expect(res.status).toBe(401);
  });

  it("rejects connecting with yourself with a 400", async () => {
    const res = await request(app)
      .post("/connections")
      .set("Authorization", bearerFor("user-1"))
      .send({ addresseeId: "user-1" });

    expect(res.status).toBe(400);
  });

  it("creates a PENDING connection request", async () => {
    client.connection.create.mockResolvedValue({
      id: "conn-1",
      requesterId: "user-1",
      addresseeId: "user-2",
      status: "PENDING",
    });

    const res = await request(app)
      .post("/connections")
      .set("Authorization", bearerFor("user-1"))
      .send({ addresseeId: "user-2" });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe("PENDING");
    expect(client.notification.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ type: "CONNECTION_REQUEST" }) })
    );
  });
});

describe("POST /connections/:id/accept", () => {
  it("rejects accepting a request that isn't addressed to the caller", async () => {
    client.connection.findUnique.mockResolvedValue({
      id: "conn-1",
      requesterId: "user-2",
      addresseeId: "user-3",
      status: "PENDING",
    });

    const res = await request(app)
      .post("/connections/conn-1/accept")
      .set("Authorization", bearerFor("user-1"));

    expect(res.status).toBe(403);
  });

  it("accepts a pending request addressed to the caller", async () => {
    client.connection.findUnique.mockResolvedValue({
      id: "conn-1",
      requesterId: "user-2",
      addresseeId: "user-1",
      status: "PENDING",
    });
    client.connection.update.mockResolvedValue({
      id: "conn-1",
      requesterId: "user-2",
      addresseeId: "user-1",
      status: "ACCEPTED",
    });
    const res = await request(app)
      .post("/connections/conn-1/accept")
      .set("Authorization", bearerFor("user-1"));

    expect(res.status).toBe(200);
    expect(res.body.status).toBe("ACCEPTED");
  });
});
