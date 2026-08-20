import { PrismaService } from "../../infrastructure/database/prisma.service";

/// Resolves a free-text search string against the Skill/StudyArea catalogs
/// (case-insensitive substring match on name) — lets a Discovery search for
/// e.g. "React" or "Machine Learning" also pull in sessions/users/notes
/// tagged with that skill/study area, not just ones whose own title, name,
/// or content happens to contain the same text.
export async function findMatchingCatalogTerms(prisma: PrismaService, search: string) {
  const [skills, studyAreas] = await Promise.all([
    prisma.client.skill.findMany({
      where: { name: { contains: search, mode: "insensitive" } },
      select: { id: true, name: true },
    }),
    prisma.client.studyArea.findMany({
      where: { name: { contains: search, mode: "insensitive" } },
      select: { id: true, name: true },
    }),
  ]);
  return { skills, studyAreas };
}
