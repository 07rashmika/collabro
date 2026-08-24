import { ReportsService } from "../reports.service";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

function makeService(overrides: { sessionFindUnique?: unknown }) {
  const session = mockModel({
    findUnique: jest.fn().mockResolvedValue(overrides.sessionFindUnique ?? null),
  });
  const report = mockModel({
    create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ id: "report-1", status: "PENDING", ...data })),
  });
  const prisma = createMockPrismaService({ session, report });
  return { service: new ReportsService(prisma), session, report };
}

function baseSession(overrides: Record<string, unknown> = {}) {
  return {
    id: "session-1",
    createdBy: "creator-1",
    participants: [{ userId: "creator-1" }, { userId: "user-2" }],
    ...overrides,
  };
}

describe("ReportsService.createReport", () => {
  afterEach(() => jest.clearAllMocks());

  it("throws 404 when the session doesn't exist", async () => {
    const { service } = makeService({ sessionFindUnique: null });

    await expect(
      service.createReport("session-1", "creator-1", { targetType: "SESSION", reason: "OTHER" })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it("throws 403 when the reporter isn't the creator or a participant", async () => {
    const { service } = makeService({ sessionFindUnique: baseSession() });

    await expect(
      service.createReport("session-1", "outsider", { targetType: "SESSION", reason: "OTHER" })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("creates a SESSION report with no reportedUserId, from the creator", async () => {
    const { service, report } = makeService({ sessionFindUnique: baseSession() });

    const result = await service.createReport("session-1", "creator-1", {
      targetType: "SESSION",
      reason: "SPAM_OR_ADVERTISING",
      details: "too many ads",
    });

    expect(report.create).toHaveBeenCalledWith({
      data: {
        targetType: "SESSION",
        reporterId: "creator-1",
        sessionId: "session-1",
        reportedUserId: null,
        reason: "SPAM_OR_ADVERTISING",
        details: "too many ads",
      },
    });
    expect(result.status).toBe("PENDING");
  });

  it("creates a SESSION report from a non-creator participant too", async () => {
    const { service, report } = makeService({ sessionFindUnique: baseSession() });

    await service.createReport("session-1", "user-2", { targetType: "SESSION", reason: "OTHER" });

    expect(report.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ reporterId: "user-2" }) })
    );
  });

  it("rejects a USER report targeting yourself with 400", async () => {
    const { service } = makeService({ sessionFindUnique: baseSession() });

    await expect(
      service.createReport("session-1", "creator-1", {
        targetType: "USER",
        reportedUserId: "creator-1",
        reason: "OTHER",
      })
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it("rejects a USER report targeting someone outside the session with 400", async () => {
    const { service } = makeService({ sessionFindUnique: baseSession() });

    await expect(
      service.createReport("session-1", "creator-1", {
        targetType: "USER",
        reportedUserId: "not-in-session",
        reason: "OTHER",
      })
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it("creates a USER report against a fellow participant", async () => {
    const { service, report } = makeService({ sessionFindUnique: baseSession() });

    const result = await service.createReport("session-1", "creator-1", {
      targetType: "USER",
      reportedUserId: "user-2",
      reason: "HARASSMENT_OR_BULLYING",
    });

    expect(report.create).toHaveBeenCalledWith({
      data: {
        targetType: "USER",
        reporterId: "creator-1",
        sessionId: "session-1",
        reportedUserId: "user-2",
        reason: "HARASSMENT_OR_BULLYING",
        details: undefined,
      },
    });
    expect(result.status).toBe("PENDING");
  });
});
