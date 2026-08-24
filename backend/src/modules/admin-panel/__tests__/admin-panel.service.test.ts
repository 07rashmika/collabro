import { AdminPanelService } from "../admin-panel.service";
import { signAdminPanelToken } from "../../../common/guards/admin-panel.guard";
import { SESSION_TTL_MS } from "../../sessions/sessions.service";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

jest.mock("../../../common/guards/admin-panel.guard", () => ({
  signAdminPanelToken: jest.fn(() => "signed-admin-token"),
}));

const mockedSign = signAdminPanelToken as jest.Mock;

function makeService(client: Record<string, unknown>) {
  const prisma = createMockPrismaService(client);
  return { service: new AdminPanelService(prisma) };
}

beforeEach(() => {
  jest.clearAllMocks();
});

describe("AdminPanelService.login", () => {
  it("issues a signed token for the correct email and password", () => {
    const { service } = makeService({});

    const result = service.login({
      email: process.env.ADMIN_EMAIL!,
      password: process.env.ADMIN_PASSWORD!,
    });

    expect(mockedSign).toHaveBeenCalledWith(process.env.ADMIN_EMAIL!);
    expect(result).toEqual({ token: "signed-admin-token" });
  });

  it("rejects an incorrect email with 401", () => {
    const { service } = makeService({});

    expect(() =>
      service.login({ email: "not-admin@x.com", password: process.env.ADMIN_PASSWORD! })
    ).toThrow(expect.objectContaining({ statusCode: 401 }));
    expect(mockedSign).not.toHaveBeenCalled();
  });

  it("rejects an incorrect password with 401", () => {
    const { service } = makeService({});

    expect(() =>
      service.login({ email: process.env.ADMIN_EMAIL!, password: "wrong-password" })
    ).toThrow(expect.objectContaining({ statusCode: 401 }));
    expect(mockedSign).not.toHaveBeenCalled();
  });
});

describe("AdminPanelService.getDashboard", () => {
  it("aggregates user/session/report counts into one summary", async () => {
    const user = mockModel({
      count: jest.fn().mockResolvedValueOnce(10).mockResolvedValueOnce(2),
    });
    const session = mockModel({
      count: jest.fn().mockResolvedValueOnce(3).mockResolvedValueOnce(1).mockResolvedValueOnce(5),
    });
    const report = mockModel({
      count: jest
        .fn()
        .mockResolvedValueOnce(2)
        .mockResolvedValueOnce(4)
        .mockResolvedValueOnce(6)
        .mockResolvedValueOnce(1),
    });
    const { service } = makeService({ user, session, report });

    const result = await service.getDashboard();

    expect(result).toEqual({
      users: { total: 10, suspended: 2 },
      sessions: { ongoing: 3, upcoming: 1, ended: 5 },
      reports: { pendingSession: 2, pendingUser: 4, pendingTotal: 6, reviewed: 6, dismissed: 1 },
    });
  });
});

describe("AdminPanelService.listUsers", () => {
  it("filters to suspended users only when status=SUSPENDED", async () => {
    const user = mockModel({
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    });
    const { service } = makeService({ user });

    await service.listUsers({ status: "SUSPENDED", page: 1, limit: 20 });

    expect(user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ isSuspended: true }) })
    );
  });

  it("searches by name or email when search is given", async () => {
    const user = mockModel({
      findMany: jest.fn().mockResolvedValue([{ id: "u1" }]),
      count: jest.fn().mockResolvedValue(1),
    });
    const { service } = makeService({ user });

    const result = await service.listUsers({ search: "jane", page: 1, limit: 20 });

    expect(user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: [
            { name: { contains: "jane", mode: "insensitive" } },
            { email: { contains: "jane", mode: "insensitive" } },
          ],
        }),
      })
    );
    expect(result).toEqual({ users: [{ id: "u1" }], total: 1, page: 1, limit: 20 });
  });
});

describe("AdminPanelService.suspendUser", () => {
  it("throws 404 when the user doesn't exist", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const { service } = makeService({ user });

    await expect(service.suspendUser("u1", {})).rejects.toMatchObject({ statusCode: 404 });
  });

  it("suspends the user, revokes refresh tokens, and leaves reports alone without a reportId", async () => {
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue({ id: "u1" }),
      update: jest.fn().mockResolvedValue({ id: "u1", isSuspended: true }),
    });
    const refreshToken = mockModel({ deleteMany: jest.fn().mockResolvedValue({ count: 1 }) });
    const report = mockModel({ updateMany: jest.fn() });
    const { service } = makeService({ user, refreshToken, report });

    await service.suspendUser("u1", { reason: "Harassment" });

    expect(user.update).toHaveBeenCalledWith({
      where: { id: "u1" },
      data: { isSuspended: true, suspendedAt: expect.any(Date), suspendedReason: "Harassment" },
      select: expect.anything(),
    });
    expect(refreshToken.deleteMany).toHaveBeenCalledWith({ where: { userId: "u1" } });
    expect(report.updateMany).not.toHaveBeenCalled();
  });

  it("also marks the originating report REVIEWED when a reportId is given", async () => {
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue({ id: "u1" }),
      update: jest.fn().mockResolvedValue({ id: "u1", isSuspended: true }),
    });
    const refreshToken = mockModel({ deleteMany: jest.fn().mockResolvedValue({}) });
    const report = mockModel({ updateMany: jest.fn().mockResolvedValue({ count: 1 }) });
    const { service } = makeService({ user, refreshToken, report });

    await service.suspendUser("u1", { reportId: "report-1" });

    expect(report.updateMany).toHaveBeenCalledWith({
      where: { id: "report-1", reportedUserId: "u1" },
      data: { status: "REVIEWED" },
    });
  });
});

describe("AdminPanelService.unsuspendUser", () => {
  it("throws 404 when the user doesn't exist", async () => {
    const user = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const { service } = makeService({ user });

    await expect(service.unsuspendUser("u1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("clears the suspension fields", async () => {
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue({ id: "u1" }),
      update: jest.fn().mockResolvedValue({ id: "u1", isSuspended: false }),
    });
    const { service } = makeService({ user });

    await service.unsuspendUser("u1");

    expect(user.update).toHaveBeenCalledWith({
      where: { id: "u1" },
      data: { isSuspended: false, suspendedAt: null, suspendedReason: null },
      select: expect.anything(),
    });
  });
});

describe("AdminPanelService.listSessions", () => {
  it("ONGOING: ACTIVE with no scheduledAt or a past one", async () => {
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    });
    const { service } = makeService({ session });

    await service.listSessions({ category: "ONGOING", page: 1, limit: 20 });

    expect(session.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: "ACTIVE",
          OR: [{ scheduledAt: null }, { scheduledAt: { lte: expect.any(Date) } }],
        }),
      })
    );
  });

  it("UPCOMING: ACTIVE with a future scheduledAt, ordered soonest first", async () => {
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    });
    const { service } = makeService({ session });

    await service.listSessions({ category: "UPCOMING", page: 1, limit: 20 });

    expect(session.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: "ACTIVE",
          scheduledAt: { gt: expect.any(Date) },
        }),
        orderBy: { scheduledAt: "asc" },
      })
    );
  });

  it("ENDED: CLOSED sessions", async () => {
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    });
    const { service } = makeService({ session });

    await service.listSessions({ category: "ENDED", page: 1, limit: 20 });

    expect(session.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ status: "CLOSED" }) })
    );
  });

  it("derives expiresAt from scheduledAt (or createdAt) plus the type's TTL", async () => {
    const scheduledAt = new Date("2026-01-01T10:00:00Z");
    const createdAt = new Date("2026-01-01T09:00:00Z");
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([
        { id: "s1", type: "VIDEO", scheduledAt, createdAt },
        { id: "s2", type: "TEXT", scheduledAt: null, createdAt },
      ]),
      count: jest.fn().mockResolvedValue(2),
    });
    const { service } = makeService({ session });

    const result = await service.listSessions({ category: "UPCOMING", page: 1, limit: 20 });

    expect(result.sessions[0].expiresAt).toEqual(
      new Date(scheduledAt.getTime() + SESSION_TTL_MS.VIDEO)
    );
    expect(result.sessions[1].expiresAt).toEqual(
      new Date(createdAt.getTime() + SESSION_TTL_MS.TEXT)
    );
  });
});

describe("AdminPanelService.listReports", () => {
  it("filters by targetType and status when both are given", async () => {
    const report = mockModel({
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    });
    const { service } = makeService({ report });

    await service.listReports({ targetType: "USER", status: "PENDING", page: 1, limit: 20 });

    expect(report.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { targetType: "USER", status: "PENDING" } })
    );
  });

  it("omits unset filters instead of passing them as undefined", async () => {
    const report = mockModel({
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    });
    const { service } = makeService({ report });

    await service.listReports({ page: 1, limit: 20 });

    expect(report.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: {} }));
  });
});

describe("AdminPanelService.updateReportStatus", () => {
  it("throws 404 when the report doesn't exist", async () => {
    const report = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const { service } = makeService({ report });

    await expect(service.updateReportStatus("r1", "DISMISSED")).rejects.toMatchObject({
      statusCode: 404,
    });
  });

  it("updates the report's status", async () => {
    const report = mockModel({
      findUnique: jest.fn().mockResolvedValue({ id: "r1" }),
      update: jest.fn().mockResolvedValue({ id: "r1", status: "DISMISSED" }),
    });
    const { service } = makeService({ report });

    const result = await service.updateReportStatus("r1", "DISMISSED");

    expect(report.update).toHaveBeenCalledWith({ where: { id: "r1" }, data: { status: "DISMISSED" } });
    expect(result.status).toBe("DISMISSED");
  });
});
