import fs from "fs/promises";
import { UsersService } from "../users.service";
import { getConnectionStatuses } from "../../connections/connections.service";
import { findMatchingCatalogTerms } from "../../../common/utils/catalog-search.util";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

jest.mock("../../connections/connections.service");
jest.mock("../../../common/utils/catalog-search.util");
jest.mock("fs/promises");

const mockedGetConnectionStatuses = getConnectionStatuses as jest.MockedFunction<
  typeof getConnectionStatuses
>;
const mockedFindMatchingCatalogTerms = findMatchingCatalogTerms as jest.MockedFunction<
  typeof findMatchingCatalogTerms
>;
const mockedUnlink = fs.unlink as jest.MockedFunction<typeof fs.unlink>;

function makeService(overrides: {
  user?: Record<string, unknown>;
  profile?: Record<string, unknown>;
  deviceToken?: Record<string, unknown>;
}) {
  const user = mockModel(overrides.user);
  const profile = mockModel(overrides.profile);
  const deviceToken = mockModel(overrides.deviceToken);
  const prisma = createMockPrismaService({ user, profile, deviceToken });
  return { service: new UsersService(prisma), user, profile, deviceToken };
}

beforeEach(() => {
  mockedGetConnectionStatuses.mockResolvedValue(new Map());
  mockedFindMatchingCatalogTerms.mockResolvedValue({ skills: [], studyAreas: [] });
  mockedUnlink.mockResolvedValue(undefined);
});

afterEach(() => jest.clearAllMocks());

describe("UsersService.getUserById", () => {
  it("throws when the target user doesn't exist", async () => {
    const { service } = makeService({ user: { findUnique: jest.fn().mockResolvedValue(null) } });

    await expect(service.getUserById("ghost", "caller-1")).rejects.toThrow("User not found");
  });

  it("attaches the caller's connection status to the returned user", async () => {
    const { service, user } = makeService({
      user: { findUnique: jest.fn().mockResolvedValue({ id: "user-2", name: "Jane" }) },
    });
    mockedGetConnectionStatuses.mockResolvedValue(new Map([["user-2", "CONNECTED"]]));

    const result = await service.getUserById("user-2", "caller-1");

    expect(user.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: "user-2" } })
    );
    expect(mockedGetConnectionStatuses).toHaveBeenCalledWith(expect.anything(), "caller-1", [
      "user-2",
    ]);
    expect(result).toEqual({ id: "user-2", name: "Jane", connectionStatus: "CONNECTED" });
  });

  it("defaults connectionStatus to NONE when no status is found", async () => {
    const { service } = makeService({
      user: { findUnique: jest.fn().mockResolvedValue({ id: "user-2", name: "Jane" }) },
    });

    const result = await service.getUserById("user-2", "caller-1");

    expect(result.connectionStatus).toBe("NONE");
  });
});

describe("UsersService.getAllUsers", () => {
  function buildUser(overrides: Record<string, unknown>) {
    return {
      id: "u-x",
      name: "Someone",
      profile: { skills: [], studyAreas: [] },
      ...overrides,
    };
  }

  it("excludes the caller and paginates the (score-sorted) results", async () => {
    const candidates = [
      buildUser({ id: "u-1" }),
      buildUser({ id: "u-2" }),
      buildUser({ id: "u-3" }),
    ];
    const { service, user, profile } = makeService({
      user: { findMany: jest.fn().mockResolvedValue(candidates) },
      profile: { findUnique: jest.fn().mockResolvedValue(null) },
    });

    const result = await service.getAllUsers("caller-1", {
      page: 1,
      limit: 2,
    } as Parameters<typeof service.getAllUsers>[1]);

    expect(user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ id: { not: "caller-1" } }) })
    );
    expect(profile.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId: "caller-1" } })
    );
    expect(result.users).toHaveLength(2);
    expect(result.meta).toEqual({ total: 3, page: 1, limit: 2, totalPages: 2 });
  });

  it("ranks a candidate sharing skills/study areas with the caller above one who shares nothing", async () => {
    const sharedSkillId = "skill-1";
    const sharedStudyAreaId = "area-1";
    const strongMatch = buildUser({
      id: "u-strong",
      profile: {
        skills: [{ skill: { id: sharedSkillId } }],
        studyAreas: [{ studyArea: { id: sharedStudyAreaId } }],
      },
    });
    const noMatch = buildUser({ id: "u-none", profile: { skills: [], studyAreas: [] } });

    const { service } = makeService({
      user: { findMany: jest.fn().mockResolvedValue([noMatch, strongMatch]) },
      profile: {
        findUnique: jest.fn().mockResolvedValue({
          skills: [{ skillId: sharedSkillId }],
          studyAreas: [{ studyAreaId: sharedStudyAreaId }],
        }),
      },
    });

    const result = await service.getAllUsers("caller-1", {
      page: 1,
      limit: 10,
    } as Parameters<typeof service.getAllUsers>[1]);

    expect(result.users[0].id).toBe("u-strong");
    expect(result.users[1].id).toBe("u-none");
  });

  it("pulls in skill/study-area matches from the catalog search when a search term is given", async () => {
    mockedFindMatchingCatalogTerms.mockResolvedValue({
      skills: [{ id: "skill-9", name: "React" }],
      studyAreas: [],
    });
    const { service, user } = makeService({
      user: { findMany: jest.fn().mockResolvedValue([]) },
      profile: { findUnique: jest.fn().mockResolvedValue(null) },
    });

    await service.getAllUsers("caller-1", {
      page: 1,
      limit: 10,
      search: "React",
    } as Parameters<typeof service.getAllUsers>[1]);

    expect(mockedFindMatchingCatalogTerms).toHaveBeenCalledWith(expect.anything(), "React");
    const whereArg = user.findMany.mock.calls[0][0].where;
    expect(whereArg.OR).toEqual(
      expect.arrayContaining([
        { profile: { skills: { some: { skillId: { in: ["skill-9"] } } } } },
      ])
    );
  });

  it("attaches connection statuses only for the paged-in users", async () => {
    const candidates = [buildUser({ id: "u-1" }), buildUser({ id: "u-2" })];
    const { service } = makeService({
      user: { findMany: jest.fn().mockResolvedValue(candidates) },
      profile: { findUnique: jest.fn().mockResolvedValue(null) },
    });
    mockedGetConnectionStatuses.mockResolvedValue(new Map([["u-1", "REQUESTED"]]));

    const result = await service.getAllUsers("caller-1", {
      page: 1,
      limit: 10,
    } as Parameters<typeof service.getAllUsers>[1]);

    const statuses = Object.fromEntries(result.users.map((u) => [u.id, u.connectionStatus]));
    expect(statuses).toEqual({ "u-1": "REQUESTED", "u-2": "NONE" });
  });
});

describe("UsersService.registerDeviceToken / unregisterDeviceToken", () => {
  it("upserts the device token keyed by the token itself, not the user", async () => {
    const { service, deviceToken } = makeService({});

    await service.registerDeviceToken("user-1", { token: "tok-1", platform: "ANDROID" } as Parameters<
      typeof service.registerDeviceToken
    >[1]);

    expect(deviceToken.upsert).toHaveBeenCalledWith({
      where: { token: "tok-1" },
      create: { token: "tok-1", userId: "user-1", platform: "ANDROID" },
      update: { userId: "user-1", platform: "ANDROID" },
    });
  });

  it("deletes only the caller's own registration for that token", async () => {
    const { service, deviceToken } = makeService({});

    await service.unregisterDeviceToken("user-1", "tok-1");

    expect(deviceToken.deleteMany).toHaveBeenCalledWith({
      where: { token: "tok-1", userId: "user-1" },
    });
  });
});

describe("UsersService.uploadAvatar", () => {
  it("throws 404 when the user doesn't exist", async () => {
    const { service } = makeService({ user: { findUnique: jest.fn().mockResolvedValue(null) } });

    await expect(
      service.uploadAvatar("ghost", { filename: "new.png" } as Express.Multer.File)
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it("sets the new avatar URL and does not attempt to unlink when there was no previous avatar", async () => {
    const { service, user } = makeService({
      user: {
        findUnique: jest.fn().mockResolvedValue({ avatarUrl: null }),
        update: jest.fn().mockResolvedValue({ id: "user-1", avatarUrl: "/uploads/avatars/new.png" }),
      },
    });

    const result = await service.uploadAvatar("user-1", { filename: "new.png" } as Express.Multer.File);

    expect(user.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { avatarUrl: "/uploads/avatars/new.png" } })
    );
    expect(mockedUnlink).not.toHaveBeenCalled();
    expect(result.avatarUrl).toBe("/uploads/avatars/new.png");
  });

  it("unlinks the previous avatar file after swapping it out", async () => {
    const { service } = makeService({
      user: {
        findUnique: jest.fn().mockResolvedValue({ avatarUrl: "/uploads/avatars/old.png" }),
        update: jest.fn().mockResolvedValue({ id: "user-1", avatarUrl: "/uploads/avatars/new.png" }),
      },
    });

    await service.uploadAvatar("user-1", { filename: "new.png" } as Express.Multer.File);

    expect(mockedUnlink).toHaveBeenCalledWith(expect.stringContaining("old.png"));
  });

  it("does not propagate an unlink failure for the old file", async () => {
    mockedUnlink.mockRejectedValue(new Error("ENOENT"));
    const { service } = makeService({
      user: {
        findUnique: jest.fn().mockResolvedValue({ avatarUrl: "/uploads/avatars/old.png" }),
        update: jest.fn().mockResolvedValue({ id: "user-1", avatarUrl: "/uploads/avatars/new.png" }),
      },
    });

    await expect(
      service.uploadAvatar("user-1", { filename: "new.png" } as Express.Multer.File)
    ).resolves.toBeDefined();
  });
});

describe("UsersService.deleteAvatar", () => {
  it("throws 404 when the user doesn't exist", async () => {
    const { service } = makeService({ user: { findUnique: jest.fn().mockResolvedValue(null) } });

    await expect(service.deleteAvatar("ghost")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("throws 404 when the user has no avatar to remove", async () => {
    const { service } = makeService({
      user: { findUnique: jest.fn().mockResolvedValue({ avatarUrl: null }) },
    });

    await expect(service.deleteAvatar("user-1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("clears the avatar URL and unlinks the file", async () => {
    const { service, user } = makeService({
      user: {
        findUnique: jest.fn().mockResolvedValue({ avatarUrl: "/uploads/avatars/old.png" }),
        update: jest.fn().mockResolvedValue({ id: "user-1", avatarUrl: null }),
      },
    });

    const result = await service.deleteAvatar("user-1");

    expect(user.update).toHaveBeenCalledWith(expect.objectContaining({ data: { avatarUrl: null } }));
    expect(mockedUnlink).toHaveBeenCalledWith(expect.stringContaining("old.png"));
    expect(result.avatarUrl).toBeNull();
  });
});

describe("UsersService.deleteMe", () => {
  it("throws when the user doesn't exist", async () => {
    const { service } = makeService({ user: { findUnique: jest.fn().mockResolvedValue(null) } });

    await expect(service.deleteMe("ghost")).rejects.toThrow("User not found");
  });

  it("deletes the caller's own account", async () => {
    const { service, user } = makeService({
      user: { findUnique: jest.fn().mockResolvedValue({ id: "user-1" }) },
    });

    await service.deleteMe("user-1");

    expect(user.delete).toHaveBeenCalledWith({ where: { id: "user-1" } });
  });
});

describe("UsersService.deleteUser (admin)", () => {
  it("throws when the target user doesn't exist", async () => {
    const { service } = makeService({ user: { findUnique: jest.fn().mockResolvedValue(null) } });

    await expect(service.deleteUser("ghost")).rejects.toThrow("User not found");
  });

  it("deletes the target user by id", async () => {
    const { service, user } = makeService({
      user: { findUnique: jest.fn().mockResolvedValue({ id: "user-2" }) },
    });

    await service.deleteUser("user-2");

    expect(user.delete).toHaveBeenCalledWith({ where: { id: "user-2" } });
  });
});
