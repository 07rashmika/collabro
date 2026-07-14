import { PrismaService } from "../../infrastructure/database/prisma.service";
import {
  CreateStudyAreaDto,
  UpdateStudyAreaDto,
  FindOrCreateStudyAreaDto,
} from "./study-areas.schema";

export class StudyAreasService {
  constructor(private readonly prisma: PrismaService) {}

  async getAllStudyAreas() {
    return this.prisma.client.studyArea.findMany({
      orderBy: { name: "asc" },
      select: {
        id: true,
        name: true,
        createdAt: true,
        _count: {
          select: { profileStudyAreas: true }, // how many students study this area
        },
      },
    });
  }

  async getStudyAreaById(id: string) {
    const studyArea = await this.prisma.client.studyArea.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        createdAt: true,
        _count: { select: { profileStudyAreas: true } },
      },
    });

    if (!studyArea) {
      throw new Error("Study area not found");
    }

    return studyArea;
  }

  async createStudyArea(dto: CreateStudyAreaDto) {
    const existing = await this.prisma.client.studyArea.findUnique({
      where: { name: dto.name },
    });

    if (existing) {
      throw new Error(`Study area "${dto.name}" already exists`);
    }

    return this.prisma.client.studyArea.create({
      data: { name: dto.name },
      select: { id: true, name: true, createdAt: true },
    });
  }

  async updateStudyArea(id: string, dto: UpdateStudyAreaDto) {
    const existing = await this.prisma.client.studyArea.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new Error("Study area not found");
    }

    if (dto.name && dto.name !== existing.name) {
      const nameClash = await this.prisma.client.studyArea.findUnique({
        where: { name: dto.name },
      });

      if (nameClash) {
        throw new Error(`Study area "${dto.name}" already exists`);
      }
    }

    return this.prisma.client.studyArea.update({
      where: { id },
      data: dto,
      select: { id: true, name: true, createdAt: true },
    });
  }

  /**
   * Student-accessible (unlike createStudyArea, admin-only) — lets the
   * profile-setup picker create a study area on the fly for any field of
   * study, not just what's been pre-seeded. Case-insensitive dedupe.
   */
  async findOrCreateStudyArea(dto: FindOrCreateStudyAreaDto) {
    const name = dto.name.trim();

    const existing = await this.prisma.client.studyArea.findFirst({
      where: { name: { equals: name, mode: "insensitive" } },
      select: { id: true, name: true, createdAt: true },
    });

    if (existing) {
      return existing;
    }

    return this.prisma.client.studyArea.create({
      data: { name },
      select: { id: true, name: true, createdAt: true },
    });
  }

  async deleteStudyArea(id: string) {
    const existing = await this.prisma.client.studyArea.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new Error("Study area not found");
    }

    await this.prisma.client.studyArea.delete({ where: { id } });
  }

  async seedStudyAreas() {
    const defaultStudyAreas = [
      "Computer Science",
      "Mathematics",
      "Physics",
      "Chemistry",
      "Biology",
      "Electrical Engineering",
      "Mechanical Engineering",
      "Civil Engineering",
      "Economics",
      "Business & Management",
      "Psychology",
      "Literature & Languages",
      "History",
      "Political Science",
      "Law",
      "Medicine",
      "Statistics",
      "Design",
    ].map((name) => ({ name }));

    const created = await this.prisma.client.studyArea.createMany({
      data: defaultStudyAreas,
      skipDuplicates: true,
    });

    return { seeded: created.count };
  }
}
