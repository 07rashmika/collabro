import { findMatchingCatalogTerms } from "../catalog-search.util";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

describe("findMatchingCatalogTerms", () => {
  it("queries both the skill and study-area catalogs with a case-insensitive contains match", async () => {
    const skill = mockModel({
      findMany: jest.fn().mockResolvedValue([{ id: "s1", name: "React" }]),
    });
    const studyArea = mockModel({
      findMany: jest.fn().mockResolvedValue([{ id: "a1", name: "Computer Science" }]),
    });
    const prisma = createMockPrismaService({ skill, studyArea });

    const result = await findMatchingCatalogTerms(prisma, "react");

    expect(skill.findMany).toHaveBeenCalledWith({
      where: { name: { contains: "react", mode: "insensitive" } },
      select: { id: true, name: true },
    });
    expect(studyArea.findMany).toHaveBeenCalledWith({
      where: { name: { contains: "react", mode: "insensitive" } },
      select: { id: true, name: true },
    });
    expect(result).toEqual({
      skills: [{ id: "s1", name: "React" }],
      studyAreas: [{ id: "a1", name: "Computer Science" }],
    });
  });

  it("returns empty arrays when nothing matches either catalog", async () => {
    const skill = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const studyArea = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const prisma = createMockPrismaService({ skill, studyArea });

    const result = await findMatchingCatalogTerms(prisma, "nonexistent");

    expect(result).toEqual({ skills: [], studyAreas: [] });
  });
});
