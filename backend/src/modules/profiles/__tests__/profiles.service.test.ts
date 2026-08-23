import { ProfilesService } from "../profiles.service";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

function buildProfile(overrides: Record<string, unknown> = {}) {
  return {
    id: "profile-1",
    bio: null,
    learningGoal: null,
    teachGoal: null,
    interests: [] as string[],
    createdAt: new Date("2026-01-01"),
    updatedAt: new Date("2026-01-01"),
    user: { id: "user-1", name: "User", email: "user-1@bedfordshire.ac.uk", avatarUrl: null },
    skills: [],
    studyAreas: [],
    ...overrides,
  };
}

describe("ProfilesService.getMyProfile", () => {
  it("throws when the caller has no profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await expect(service.getMyProfile("user-1")).rejects.toThrow("Profile not found");
  });

  it("returns the caller's profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    const result = await service.getMyProfile("user-1");
    expect(result.id).toBe("profile-1");
  });
});

describe("ProfilesService.getProfileByUserId", () => {
  it("throws when the target user has no profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await expect(service.getProfileByUserId("user-2")).rejects.toThrow("Profile not found");
  });

  it("returns the target user's profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    const result = await service.getProfileByUserId("user-1");
    expect(result.id).toBe("profile-1");
  });
});

describe("ProfilesService.createProfile", () => {
  it("rejects creating a second profile for the same user", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await expect(
      service.createProfile("user-1", { interests: [] } as never)
    ).rejects.toThrow("Profile already exists for this user");
  });

  it("creates a profile with nested skills and study areas", async () => {
    const profile = mockModel({
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue(buildProfile()),
    });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await service.createProfile("user-1", {
      bio: "hi",
      interests: ["ai"],
      skills: [{ skillId: "s1", level: "BEGINNER" }],
      studyAreaIds: ["a1"],
    } as never);

    expect(profile.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          userId: "user-1",
          skills: { create: [{ skillId: "s1", level: "BEGINNER" }] },
          studyAreas: { create: [{ studyAreaId: "a1" }] },
        }),
      })
    );
  });
});

describe("ProfilesService.updateProfile", () => {
  it("throws when the caller has no profile yet", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await expect(
      service.updateProfile("user-1", { bio: "new" } as never)
    ).rejects.toThrow("Profile not found");
  });

  it("updates the caller's profile fields", async () => {
    const profile = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildProfile()),
      update: jest.fn().mockResolvedValue(buildProfile({ bio: "new bio" })),
    });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    const result = await service.updateProfile("user-1", { bio: "new bio" } as never);
    expect(result.bio).toBe("new bio");
  });
});

describe("ProfilesService.addSkill", () => {
  it("throws when the caller has no profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await expect(
      service.addSkill("user-1", { skillId: "s1", level: "BEGINNER" } as never)
    ).rejects.toThrow("Profile not found — create your profile first");
  });

  it("throws when the skill doesn't exist", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const skill = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile, skill }));

    await expect(
      service.addSkill("user-1", { skillId: "missing", level: "BEGINNER" } as never)
    ).rejects.toThrow("Skill not found");
  });

  it("updates the level when the skill is already on the profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const skill = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "s1" }) });
    const profileSkill = mockModel({
      findUnique: jest.fn().mockResolvedValue({ profileId: "profile-1", skillId: "s1" }),
      update: jest.fn().mockResolvedValue({ level: "ADVANCED", skill: { id: "s1" } }),
    });
    const service = new ProfilesService(createMockPrismaService({ profile, skill, profileSkill }));

    const result = await service.addSkill("user-1", { skillId: "s1", level: "ADVANCED" } as never);

    expect(profileSkill.update).toHaveBeenCalled();
    expect(profileSkill.create).not.toHaveBeenCalled();
    expect(result.level).toBe("ADVANCED");
  });

  it("creates a new profile skill when not already added", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const skill = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "s1" }) });
    const profileSkill = mockModel({
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({ level: "BEGINNER", skill: { id: "s1" } }),
    });
    const service = new ProfilesService(createMockPrismaService({ profile, skill, profileSkill }));

    const result = await service.addSkill("user-1", { skillId: "s1", level: "BEGINNER" } as never);

    expect(profileSkill.create).toHaveBeenCalled();
    expect(result.level).toBe("BEGINNER");
  });
});

describe("ProfilesService.removeSkill", () => {
  it("throws when the caller has no profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await expect(
      service.removeSkill("user-1", { skillId: "s1" } as never)
    ).rejects.toThrow("Profile not found");
  });

  it("throws when the skill isn't on the profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const profileSkill = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile, profileSkill }));

    await expect(
      service.removeSkill("user-1", { skillId: "s1" } as never)
    ).rejects.toThrow("Skill not on your profile");
  });

  it("deletes the profile skill when present", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const profileSkill = mockModel({
      findUnique: jest.fn().mockResolvedValue({ profileId: "profile-1", skillId: "s1" }),
      delete: jest.fn().mockResolvedValue(undefined),
    });
    const service = new ProfilesService(createMockPrismaService({ profile, profileSkill }));

    await service.removeSkill("user-1", { skillId: "s1" } as never);

    expect(profileSkill.delete).toHaveBeenCalledWith({
      where: { profileId_skillId: { profileId: "profile-1", skillId: "s1" } },
    });
  });
});

describe("ProfilesService.addStudyArea", () => {
  it("throws when the caller has no profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await expect(
      service.addStudyArea("user-1", { studyAreaId: "a1" } as never)
    ).rejects.toThrow("Profile not found — create your profile first");
  });

  it("throws when the study area doesn't exist", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const studyArea = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile, studyArea }));

    await expect(
      service.addStudyArea("user-1", { studyAreaId: "missing" } as never)
    ).rejects.toThrow("Study area not found");
  });

  it("returns the existing link without creating a duplicate", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const studyArea = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "a1" }) });
    const findUniqueOrThrow = jest
      .fn()
      .mockResolvedValue({ studyArea: { id: "a1", name: "Computer Science" } });
    const profileStudyArea = mockModel({
      findUnique: jest.fn().mockResolvedValue({ profileId: "profile-1", studyAreaId: "a1" }),
      findUniqueOrThrow,
    });
    const service = new ProfilesService(
      createMockPrismaService({ profile, studyArea, profileStudyArea })
    );

    const result = await service.addStudyArea("user-1", { studyAreaId: "a1" } as never);

    expect(findUniqueOrThrow).toHaveBeenCalled();
    expect(profileStudyArea.create).not.toHaveBeenCalled();
    expect(result.studyArea.id).toBe("a1");
  });

  it("creates a new profile study area when not already added", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const studyArea = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "a1" }) });
    const profileStudyArea = mockModel({
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({ studyArea: { id: "a1", name: "Computer Science" } }),
    });
    const service = new ProfilesService(
      createMockPrismaService({ profile, studyArea, profileStudyArea })
    );

    const result = await service.addStudyArea("user-1", { studyAreaId: "a1" } as never);

    expect(profileStudyArea.create).toHaveBeenCalled();
    expect(result.studyArea.id).toBe("a1");
  });
});

describe("ProfilesService.removeStudyArea", () => {
  it("throws when the caller has no profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await expect(
      service.removeStudyArea("user-1", { studyAreaId: "a1" } as never)
    ).rejects.toThrow("Profile not found");
  });

  it("throws when the study area isn't on the profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const profileStudyArea = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile, profileStudyArea }));

    await expect(
      service.removeStudyArea("user-1", { studyAreaId: "a1" } as never)
    ).rejects.toThrow("Study area not on your profile");
  });

  it("deletes the profile study area when present", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(buildProfile()) });
    const profileStudyArea = mockModel({
      findUnique: jest.fn().mockResolvedValue({ profileId: "profile-1", studyAreaId: "a1" }),
      delete: jest.fn().mockResolvedValue(undefined),
    });
    const service = new ProfilesService(createMockPrismaService({ profile, profileStudyArea }));

    await service.removeStudyArea("user-1", { studyAreaId: "a1" } as never);

    expect(profileStudyArea.delete).toHaveBeenCalledWith({
      where: { profileId_studyAreaId: { profileId: "profile-1", studyAreaId: "a1" } },
    });
  });
});

describe("ProfilesService.deleteProfile", () => {
  it("throws when the caller has no profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await expect(service.deleteProfile("user-1")).rejects.toThrow("Profile not found");
  });

  it("deletes the caller's profile", async () => {
    const profile = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildProfile()),
      delete: jest.fn().mockResolvedValue(undefined),
    });
    const service = new ProfilesService(createMockPrismaService({ profile }));

    await service.deleteProfile("user-1");

    expect(profile.delete).toHaveBeenCalledWith({ where: { userId: "user-1" } });
  });
});
