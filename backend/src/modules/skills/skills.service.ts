import { PrismaService } from "../../infrastructure/database/prisma.service";
import { CreateSkillDto, UpdateSkillDto, FindOrCreateSkillDto } from "./skills.schema";

const SKILLS_API_URL = "https://api.apilayer.com/skills";

export class SkillsService {
  constructor(private readonly prisma: PrismaService) {}

  async getAllSkills() {
    return this.prisma.client.skill.findMany({
      orderBy: [{ category: "asc" }, { name: "asc" }],
      select: {
        id: true,
        name: true,
        category: true,
        createdAt: true,
        _count: {
          select: { profileSkills: true }, // how many students have this skill
        },
      },
    });
  }

  async getSkillsByCategory(category: string) {
    return this.prisma.client.skill.findMany({
      where: {
        category: { equals: category, mode: "insensitive" },
      },
      orderBy: { name: "asc" },
      select: {
        id: true,
        name: true,
        category: true,
        _count: { select: { profileSkills: true } },
      },
    });
  }

  async getSkillById(id: string) {
    const skill = await this.prisma.client.skill.findUnique({
      where: { id },
      select: {
        id: true,
        name: true,
        category: true,
        createdAt: true,
        _count: { select: { profileSkills: true } },
      },
    });

    if (!skill) {
      throw new Error("Skill not found");
    }

    return skill;
  }

  async createSkill(dto: CreateSkillDto) {
    const existing = await this.prisma.client.skill.findUnique({
      where: { name: dto.name },
    });

    if (existing) {
      throw new Error(`Skill "${dto.name}" already exists`);
    }

    return this.prisma.client.skill.create({
      data: {
        name: dto.name,
        category: dto.category,
      },
      select: {
        id: true,
        name: true,
        category: true,
        createdAt: true,
      },
    });
  }

  async updateSkill(id: string, dto: UpdateSkillDto) {
    const existing = await this.prisma.client.skill.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new Error("Skill not found");
    }

    // check name clash with another skill
    if (dto.name && dto.name !== existing.name) {
      const nameClash = await this.prisma.client.skill.findUnique({
        where: { name: dto.name },
      });

      if (nameClash) {
        throw new Error(`Skill "${dto.name}" already exists`);
      }
    }

    return this.prisma.client.skill.update({
      where: { id },
      data: dto,
      select: {
        id: true,
        name: true,
        category: true,
        createdAt: true,
      },
    });
  }

  async deleteSkill(id: string) {
    const existing = await this.prisma.client.skill.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new Error("Skill not found");
    }

    await this.prisma.client.skill.delete({ where: { id } });
  }

  /**
   * Any authenticated student can call this (unlike createSkill, which is
   * admin-only) — it's how the profile-setup skill picker lets a student
   * type a skill that isn't in the catalog yet without needing an admin to
   * pre-seed it. Case-insensitive dedupe so "python" and "Python" collapse
   * to one row; category defaults to "General" since a student typing a
   * skill name has no reason to also classify it.
   */
  async findOrCreateSkill(dto: FindOrCreateSkillDto) {
    const name = dto.name.trim();

    const existing = await this.prisma.client.skill.findFirst({
      where: { name: { equals: name, mode: "insensitive" } },
      select: { id: true, name: true, category: true, createdAt: true },
    });

    if (existing) {
      return existing;
    }

    return this.prisma.client.skill.create({
      data: { name, category: dto.category?.trim() || "General" },
      select: { id: true, name: true, category: true, createdAt: true },
    });
  }

  /**
   * Live typeahead suggestions from the apilayer Skills API
   * (https://marketplace.apilayer.com/skills-api) — a 70,000+ entry catalog,
   * far broader than what any one deployment's local `Skill` table has been
   * seeded with. Returns bare names; picking one still goes through
   * `findOrCreateSkill` to materialize a local row with a real id.
   */
  async searchExternalSkills(query: string, count = 10) {
    const apiKey = process.env.SKILLS_API_KEY;
    if (!apiKey) {
      throw new Error("Skill search is not configured on this server");
    }

    const url = new URL(SKILLS_API_URL);
    url.searchParams.set("q", query);
    url.searchParams.set("count", String(count));

    const response = await fetch(url, { headers: { apikey: apiKey } });
    if (!response.ok) {
      throw new Error(`Skill search failed (${response.status})`);
    }

    const results = (await response.json()) as unknown;
    if (!Array.isArray(results)) return [];
    return results.filter((r): r is string => typeof r === "string");
  }

  async getCategories() {
    const skills = await this.prisma.client.skill.findMany({
      select: { category: true },
      distinct: ["category"],
      orderBy: { category: "asc" },
    });

    return skills.map((s) => s.category);
  }

  async seedSkills() {
    const defaultSkills = [
      // CS Fundamentals
      { name: "Data Structures", category: "CS Fundamentals" },
      { name: "Algorithms", category: "CS Fundamentals" },
      { name: "Operating Systems", category: "CS Fundamentals" },
      { name: "Computer Networks", category: "CS Fundamentals" },
      { name: "Database Systems", category: "CS Fundamentals" },
      // Frontend
      { name: "React", category: "Frontend" },
      { name: "Flutter", category: "Frontend" },
      { name: "HTML & CSS", category: "Frontend" },
      { name: "TypeScript", category: "Frontend" },
      { name: "Next.js", category: "Frontend" },
      // Backend
      { name: "Node.js", category: "Backend" },
      { name: "NestJS", category: "Backend" },
      { name: "Express", category: "Backend" },
      { name: "REST API Design", category: "Backend" },
      { name: "GraphQL", category: "Backend" },
      // Data & AI
      { name: "Python", category: "Data & AI" },
      { name: "Machine Learning", category: "Data & AI" },
      { name: "Data Analysis", category: "Data & AI" },
      { name: "TensorFlow", category: "Data & AI" },
      // DevOps
      { name: "Docker", category: "DevOps" },
      { name: "Git", category: "DevOps" },
      { name: "CI/CD", category: "DevOps" },
      // Mobile
      { name: "Android (Kotlin)", category: "Mobile" },
      { name: "iOS (Swift)", category: "Mobile" },
    ];

    const created = await this.prisma.client.skill.createMany({
      data: defaultSkills,
      skipDuplicates: true,
    });

    return { seeded: created.count };
  }
}