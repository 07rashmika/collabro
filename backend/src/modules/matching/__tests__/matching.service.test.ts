import { MatchingService } from "../matching.service";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

function buildProfile(overrides: Record<string, unknown>) {
  return {
    userId: "candidate-1",
    bio: null,
    learningGoal: null,
    teachGoal: null,
    interests: [] as string[],
    user: { id: "candidate-1", name: "Candidate", email: "c@bedfordshire.ac.uk", avatarUrl: null },
    skills: [] as unknown[],
    studyAreas: [] as unknown[],
    ...overrides,
  };
}

describe("MatchingService.getSuggestions", () => {
  const myProfile = buildProfile({
    userId: "caller-1",
    user: { id: "caller-1", name: "Caller", email: "caller@bedfordshire.ac.uk", avatarUrl: null },
    learningGoal: "react",
    interests: ["UI Design"],
    skills: [
      { level: "BEGINNER", skill: { id: "s1", name: "React", category: "Frontend" } },
      { level: "BEGINNER", skill: { id: "s2", name: "Node", category: "Backend" } },
    ],
    studyAreas: [{ studyArea: { id: "a1", name: "Computer Science" } }],
  });

  function makeService(otherProfiles: unknown[], connections: unknown[] = []) {
    const profile = mockModel({
      findUnique: jest.fn().mockResolvedValue(myProfile),
      findMany: jest.fn().mockResolvedValue(otherProfiles),
    });
    const connection = mockModel({ findMany: jest.fn().mockResolvedValue(connections) });
    const prisma = createMockPrismaService({ profile, connection });
    return new MatchingService(prisma);
  }

  it("rejects a caller with no profile", async () => {
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const prisma = createMockPrismaService({ profile, connection: mockModel() });
    const service = new MatchingService(prisma);

    await expect(
      service.getSuggestions("caller-1", { minScore: 0, limit: 10 })
    ).rejects.toThrow("You need to set up your profile");
  });

  it("rejects a caller with no skills on their profile", async () => {
    const profile = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildProfile({ userId: "caller-1", skills: [] })),
    });
    const prisma = createMockPrismaService({ profile, connection: mockModel() });
    const service = new MatchingService(prisma);

    await expect(
      service.getSuggestions("caller-1", { minScore: 0, limit: 10 })
    ).rejects.toThrow("Add at least one skill");
  });

  it("returns no suggestions when no other student shares a skill category", async () => {
    const service = makeService([]);
    const result = await service.getSuggestions("caller-1", { minScore: 0, limit: 10 });
    expect(result).toEqual({ suggestions: [], total: 0 });
  });

  it("excludes candidates the caller is already connected to", async () => {
    const candidate = buildProfile({
      skills: [{ level: "ADVANCED", skill: { id: "s1", name: "React", category: "Frontend" } }],
    });
    const service = makeService([candidate], [
      { requesterId: "caller-1", addresseeId: "candidate-1", status: "ACCEPTED" },
    ]);

    const result = await service.getSuggestions("caller-1", { minScore: 0, limit: 10 });
    expect(result).toEqual({ suggestions: [], total: 0 });
  });

  it("excludes a candidate that scores zero even when minScore is 0", async () => {
    // Shares no skill, study area, interest, or goal with the caller at all.
    const candidate = buildProfile({
      skills: [{ level: "BEGINNER", skill: { id: "s9", name: "Cooking", category: "Lifestyle" } }],
    });
    const service = makeService([candidate]);

    const result = await service.getSuggestions("caller-1", { minScore: 0, limit: 10 });
    expect(result.suggestions).toHaveLength(0);
  });

  it("computes the weighted compatibility score for a strong mentor-style match", async () => {
    const candidate = buildProfile({
      teachGoal: "learn react basics",
      interests: ["ui design"],
      skills: [{ level: "ADVANCED", skill: { id: "s1", name: "React", category: "Frontend" } }],
      studyAreas: [{ studyArea: { id: "a1", name: "Computer Science" } }],
    });
    const service = makeService([candidate]);

    const result = await service.getSuggestions("caller-1", { minScore: 0, limit: 10 });

    expect(result.total).toBe(1);
    const [match] = result.suggestions;
    // 30 * (1/2) shared skills + min(2 * 25/4, 25) complementary + 10 goal
    // alignment + 20 shared study area + 15 shared interest = 72.5 → 73.
    expect(match.totalScore).toBe(73);
    expect(match.matchedSkills).toEqual(["React"]);
    expect(match.complementarySkills).toEqual(["React"]);
    expect(match.matchedStudyAreas).toEqual(["Computer Science"]);
    expect(match.matchedInterests).toEqual(["ui design"]);
    expect(match.connectionStatus).toBe("NONE");
    expect(match.aiReason).toContain("Can help you level up in React");
  });

  it("ranks candidates by score, highest first, and respects `limit`", async () => {
    const weakMatch = buildProfile({
      userId: "candidate-weak",
      skills: [{ level: "BEGINNER", skill: { id: "s2", name: "Node", category: "Backend" } }],
    });
    const strongMatch = buildProfile({
      userId: "candidate-strong",
      skills: [
        { level: "BEGINNER", skill: { id: "s1", name: "React", category: "Frontend" } },
        { level: "BEGINNER", skill: { id: "s2", name: "Node", category: "Backend" } },
      ],
    });
    const service = makeService([weakMatch, strongMatch]);

    const result = await service.getSuggestions("caller-1", { minScore: 0, limit: 1 });

    expect(result.suggestions).toHaveLength(1);
    expect(result.suggestions[0].student.userId).toBe("candidate-strong");
  });

  it("discards candidates below the caller-supplied minScore threshold", async () => {
    const weakMatch = buildProfile({
      skills: [{ level: "BEGINNER", skill: { id: "s2", name: "Node", category: "Backend" } }],
    });
    const service = makeService([weakMatch]);

    // Shared skill ratio alone (1/2 * 30 = 15) is below a 50 threshold.
    const result = await service.getSuggestions("caller-1", { minScore: 50, limit: 10 });
    expect(result.suggestions).toHaveLength(0);
  });
});
