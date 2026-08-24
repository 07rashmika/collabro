import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    user: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      count: jest.fn(),
    },
    session: {
      findMany: jest.fn(),
      count: jest.fn(),
    },
    report: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
      count: jest.fn(),
    },
    refreshToken: { deleteMany: jest.fn() },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { signAdminPanelToken } from "../../common/guards/admin-panel.guard";

const client = PrismaService.getInstance().client as unknown as {
  user: { findUnique: jest.Mock; findMany: jest.Mock; update: jest.Mock; count: jest.Mock };
  session: { findMany: jest.Mock; count: jest.Mock };
  report: {
    findUnique: jest.Mock;
    findMany: jest.Mock;
    update: jest.Mock;
    updateMany: jest.Mock;
    count: jest.Mock;
  };
  refreshToken: { deleteMany: jest.Mock };
};

function adminBearer() {
  return `Bearer ${signAdminPanelToken(process.env.ADMIN_EMAIL!)}`;
}

afterEach(() => jest.clearAllMocks());

describe("POST /api/admin/login", () => {
  it("rejects a missing password with a 400 validation error", async () => {
    const res = await request(app)
      .post("/api/admin/login")
      .send({ email: process.env.ADMIN_EMAIL });

    expect(res.status).toBe(400);
  });

  it("rejects incorrect credentials with 401", async () => {
    const res = await request(app)
      .post("/api/admin/login")
      .send({ email: process.env.ADMIN_EMAIL, password: "wrong-password" });

    expect(res.status).toBe(401);
  });

  it("issues a token for the correct credentials", async () => {
    const res = await request(app)
      .post("/api/admin/login")
      .send({ email: process.env.ADMIN_EMAIL, password: process.env.ADMIN_PASSWORD });

    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
  });
});

describe("admin panel session guard", () => {
  it("rejects a request with no Authorization header", async () => {
    const res = await request(app).get("/api/admin/dashboard");
    expect(res.status).toBe(401);
  });

  it("rejects a student JWT (not an admin panel token)", async () => {
    const res = await request(app)
      .get("/api/admin/dashboard")
      .set("Authorization", "Bearer not-an-admin-token");

    expect(res.status).toBe(401);
  });
});

describe("GET /api/admin/dashboard", () => {
  it("returns aggregated counts", async () => {
    client.user.count.mockResolvedValueOnce(10).mockResolvedValueOnce(2);
    client.session.count.mockResolvedValueOnce(3).mockResolvedValueOnce(1).mockResolvedValueOnce(5);
    client.report.count
      .mockResolvedValueOnce(2)
      .mockResolvedValueOnce(4)
      .mockResolvedValueOnce(6)
      .mockResolvedValueOnce(1);

    const res = await request(app).get("/api/admin/dashboard").set("Authorization", adminBearer());

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      users: { total: 10, suspended: 2 },
      sessions: { ongoing: 3, upcoming: 1, ended: 5 },
      reports: { pendingSession: 2, pendingUser: 4, pendingTotal: 6, reviewed: 6, dismissed: 1 },
    });
  });
});

describe("GET /api/admin/users", () => {
  it("returns the paginated user list", async () => {
    client.user.findMany.mockResolvedValue([{ id: "u1" }]);
    client.user.count.mockResolvedValue(1);

    const res = await request(app).get("/api/admin/users").set("Authorization", adminBearer());

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ users: [{ id: "u1" }], total: 1, page: 1, limit: 20 });
  });
});

describe("PATCH /api/admin/users/:id/suspend", () => {
  it("responds with 404 when the user doesn't exist", async () => {
    client.user.findUnique.mockResolvedValue(null);

    const res = await request(app)
      .patch("/api/admin/users/u1/suspend")
      .set("Authorization", adminBearer())
      .send({ reason: "Harassment" });

    expect(res.status).toBe(404);
  });

  it("suspends the user and revokes their refresh tokens", async () => {
    client.user.findUnique.mockResolvedValue({ id: "u1" });
    client.user.update.mockResolvedValue({ id: "u1", isSuspended: true });
    client.refreshToken.deleteMany.mockResolvedValue({ count: 1 });

    const res = await request(app)
      .patch("/api/admin/users/u1/suspend")
      .set("Authorization", adminBearer())
      .send({ reason: "Harassment" });

    expect(res.status).toBe(200);
    expect(res.body.isSuspended).toBe(true);
    expect(client.refreshToken.deleteMany).toHaveBeenCalledWith({ where: { userId: "u1" } });
  });
});

describe("PATCH /api/admin/users/:id/unsuspend", () => {
  it("clears the suspension", async () => {
    client.user.findUnique.mockResolvedValue({ id: "u1" });
    client.user.update.mockResolvedValue({ id: "u1", isSuspended: false });

    const res = await request(app)
      .patch("/api/admin/users/u1/unsuspend")
      .set("Authorization", adminBearer());

    expect(res.status).toBe(200);
    expect(res.body.isSuspended).toBe(false);
  });
});

describe("GET /api/admin/sessions", () => {
  it("rejects a missing category with a 400 validation error", async () => {
    const res = await request(app).get("/api/admin/sessions").set("Authorization", adminBearer());
    expect(res.status).toBe(400);
  });

  it("returns the paginated session list for a category", async () => {
    client.session.findMany.mockResolvedValue([]);
    client.session.count.mockResolvedValue(0);

    const res = await request(app)
      .get("/api/admin/sessions")
      .query({ category: "ONGOING" })
      .set("Authorization", adminBearer());

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ sessions: [], total: 0, page: 1, limit: 20 });
  });
});

describe("GET /api/admin/reports", () => {
  it("returns the paginated report list", async () => {
    client.report.findMany.mockResolvedValue([]);
    client.report.count.mockResolvedValue(0);

    const res = await request(app).get("/api/admin/reports").set("Authorization", adminBearer());

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ reports: [], total: 0, page: 1, limit: 20 });
  });
});

describe("PATCH /api/admin/reports/:id", () => {
  it("responds with 404 when the report doesn't exist", async () => {
    client.report.findUnique.mockResolvedValue(null);

    const res = await request(app)
      .patch("/api/admin/reports/r1")
      .set("Authorization", adminBearer())
      .send({ status: "DISMISSED" });

    expect(res.status).toBe(404);
  });

  it("updates the report's status", async () => {
    client.report.findUnique.mockResolvedValue({ id: "r1" });
    client.report.update.mockResolvedValue({ id: "r1", status: "DISMISSED" });

    const res = await request(app)
      .patch("/api/admin/reports/r1")
      .set("Authorization", adminBearer())
      .send({ status: "DISMISSED" });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe("DISMISSED");
  });
});
