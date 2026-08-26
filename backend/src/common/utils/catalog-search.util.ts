import { PrismaService } from "../../infrastructure/database/prisma.service";

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
