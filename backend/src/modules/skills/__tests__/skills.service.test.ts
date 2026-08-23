import { SkillsService } from "../skills.service";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

describe("SkillsService", () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    delete process.env.SKILLS_API_KEY;
  });

  describe("getAllSkills", () => {
    it("returns all skills ordered by category then name", async () => {
      const skill = mockModel({
        findMany: jest.fn().mockResolvedValue([{ id: "s1", name: "React", category: "Frontend" }]),
      });
      const service = new SkillsService(createMockPrismaService({ skill }));

      const result = await service.getAllSkills();

      expect(result).toEqual([{ id: "s1", name: "React", category: "Frontend" }]);
      expect(skill.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ orderBy: [{ category: "asc" }, { name: "asc" }] })
      );
    });
  });

  describe("getSkillsByCategory", () => {
    it("filters case-insensitively by category", async () => {
      const skill = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
      const service = new SkillsService(createMockPrismaService({ skill }));

      await service.getSkillsByCategory("frontend");

      expect(skill.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { category: { equals: "frontend", mode: "insensitive" } } })
      );
    });
  });

  describe("getSkillById", () => {
    it("throws when the skill doesn't exist", async () => {
      const skill = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
      const service = new SkillsService(createMockPrismaService({ skill }));

      await expect(service.getSkillById("missing")).rejects.toThrow("Skill not found");
    });

    it("returns the skill when found", async () => {
      const skill = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "s1", name: "React" }) });
      const service = new SkillsService(createMockPrismaService({ skill }));

      await expect(service.getSkillById("s1")).resolves.toEqual({ id: "s1", name: "React" });
    });
  });

  describe("createSkill", () => {
    it("rejects a duplicate name", async () => {
      const skill = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "existing" }) });
      const service = new SkillsService(createMockPrismaService({ skill }));

      await expect(
        service.createSkill({ name: "React", category: "Frontend" })
      ).rejects.toThrow('Skill "React" already exists');
    });

    it("creates a new skill", async () => {
      const skill = mockModel({
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: "s1", name: "React", category: "Frontend" }),
      });
      const service = new SkillsService(createMockPrismaService({ skill }));

      const result = await service.createSkill({ name: "React", category: "Frontend" });

      expect(result).toEqual({ id: "s1", name: "React", category: "Frontend" });
      expect(skill.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: { name: "React", category: "Frontend" } })
      );
    });
  });

  describe("updateSkill", () => {
    it("throws when the skill doesn't exist", async () => {
      const skill = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
      const service = new SkillsService(createMockPrismaService({ skill }));

      await expect(service.updateSkill("missing", { name: "Vue" })).rejects.toThrow("Skill not found");
    });

    it("rejects renaming to a name that clashes with another skill", async () => {
      const skill = mockModel({
        findUnique: jest
          .fn()
          .mockResolvedValueOnce({ id: "s1", name: "React" })
          .mockResolvedValueOnce({ id: "s2", name: "Vue" }),
      });
      const service = new SkillsService(createMockPrismaService({ skill }));

      await expect(service.updateSkill("s1", { name: "Vue" })).rejects.toThrow('Skill "Vue" already exists');
    });

    it("updates the skill when there's no name clash", async () => {
      const skill = mockModel({
        findUnique: jest.fn().mockResolvedValueOnce({ id: "s1", name: "React" }).mockResolvedValueOnce(null),
        update: jest.fn().mockResolvedValue({ id: "s1", name: "Vue", category: "Frontend" }),
      });
      const service = new SkillsService(createMockPrismaService({ skill }));

      const result = await service.updateSkill("s1", { name: "Vue" });

      expect(result).toEqual({ id: "s1", name: "Vue", category: "Frontend" });
    });

    it("skips the name-clash check when name isn't being changed", async () => {
      const skill = mockModel({
        findUnique: jest.fn().mockResolvedValueOnce({ id: "s1", name: "React" }),
        update: jest.fn().mockResolvedValue({ id: "s1", name: "React", category: "Backend" }),
      });
      const service = new SkillsService(createMockPrismaService({ skill }));

      await service.updateSkill("s1", { category: "Backend" });

      expect(skill.findUnique).toHaveBeenCalledTimes(1);
    });
  });

  describe("deleteSkill", () => {
    it("throws when the skill doesn't exist", async () => {
      const skill = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
      const service = new SkillsService(createMockPrismaService({ skill }));

      await expect(service.deleteSkill("missing")).rejects.toThrow("Skill not found");
    });

    it("deletes an existing skill", async () => {
      const skill = mockModel({
        findUnique: jest.fn().mockResolvedValue({ id: "s1" }),
        delete: jest.fn().mockResolvedValue({ id: "s1" }),
      });
      const service = new SkillsService(createMockPrismaService({ skill }));

      await service.deleteSkill("s1");

      expect(skill.delete).toHaveBeenCalledWith({ where: { id: "s1" } });
    });
  });

  describe("findOrCreateSkill", () => {
    it("returns the existing skill case-insensitively instead of creating a duplicate", async () => {
      const skill = mockModel({
        findFirst: jest.fn().mockResolvedValue({ id: "s1", name: "Python", category: "Data & AI" }),
        create: jest.fn(),
      });
      const service = new SkillsService(createMockPrismaService({ skill }));

      const result = await service.findOrCreateSkill({ name: "python" });

      expect(result).toEqual({ id: "s1", name: "Python", category: "Data & AI" });
      expect(skill.create).not.toHaveBeenCalled();
    });

    it("creates a new skill, trimming the name and defaulting to General", async () => {
      const skill = mockModel({
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: "s2", name: "Rust", category: "General" }),
      });
      const service = new SkillsService(createMockPrismaService({ skill }));

      const result = await service.findOrCreateSkill({ name: "  Rust  " });

      expect(skill.create).toHaveBeenCalledWith(
        expect.objectContaining({ data: { name: "Rust", category: "General" } })
      );
      expect(result).toEqual({ id: "s2", name: "Rust", category: "General" });
    });
  });

  describe("searchExternalSkills", () => {
    it("throws when SKILLS_API_KEY isn't configured", async () => {
      const service = new SkillsService(createMockPrismaService({}));

      await expect(service.searchExternalSkills("py")).rejects.toThrow(
        "Skill search is not configured on this server"
      );
    });

    it("throws when the external API responds with a non-OK status", async () => {
      process.env.SKILLS_API_KEY = "test-key";
      global.fetch = jest.fn().mockResolvedValue({ ok: false, status: 502 }) as unknown as typeof fetch;
      const service = new SkillsService(createMockPrismaService({}));

      await expect(service.searchExternalSkills("py")).rejects.toThrow("Skill search failed (502)");
    });

    it("returns only string results from the external API", async () => {
      process.env.SKILLS_API_KEY = "test-key";
      global.fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ["Python", "PyTorch", 42, null],
      }) as unknown as typeof fetch;
      const service = new SkillsService(createMockPrismaService({}));

      const result = await service.searchExternalSkills("py");

      expect(result).toEqual(["Python", "PyTorch"]);
    });

    it("returns an empty array when the external API doesn't return an array", async () => {
      process.env.SKILLS_API_KEY = "test-key";
      global.fetch = jest.fn().mockResolvedValue({ ok: true, json: async () => ({}) }) as unknown as typeof fetch;
      const service = new SkillsService(createMockPrismaService({}));

      const result = await service.searchExternalSkills("py");

      expect(result).toEqual([]);
    });
  });

  describe("getCategories", () => {
    it("returns distinct category names", async () => {
      const skill = mockModel({
        findMany: jest.fn().mockResolvedValue([{ category: "Frontend" }, { category: "Backend" }]),
      });
      const service = new SkillsService(createMockPrismaService({ skill }));

      const result = await service.getCategories();

      expect(result).toEqual(["Frontend", "Backend"]);
    });
  });

  describe("seedSkills", () => {
    it("bulk-creates the default catalog, skipping duplicates", async () => {
      const skill = mockModel({ createMany: jest.fn().mockResolvedValue({ count: 24 }) });
      const service = new SkillsService(createMockPrismaService({ skill }));

      const result = await service.seedSkills();

      expect(result).toEqual({ seeded: 24 });
      expect(skill.createMany).toHaveBeenCalledWith(expect.objectContaining({ skipDuplicates: true }));
    });
  });
});
