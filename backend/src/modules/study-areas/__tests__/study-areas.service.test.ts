import { StudyAreasService } from "../study-areas.service";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

describe("StudyAreasService", () => {
  describe("getAllStudyAreas", () => {
    it("returns all study areas ordered by name", async () => {
      const studyArea = mockModel({
        findMany: jest.fn().mockResolvedValue([{ id: "a1", name: "Computer Science" }]),
      });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      const result = await service.getAllStudyAreas();

      expect(result).toEqual([{ id: "a1", name: "Computer Science" }]);
      expect(studyArea.findMany).toHaveBeenCalledWith(expect.objectContaining({ orderBy: { name: "asc" } }));
    });
  });

  describe("getStudyAreaById", () => {
    it("throws when the study area doesn't exist", async () => {
      const studyArea = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      await expect(service.getStudyAreaById("missing")).rejects.toThrow("Study area not found");
    });

    it("returns the study area when found", async () => {
      const studyArea = mockModel({
        findUnique: jest.fn().mockResolvedValue({ id: "a1", name: "Computer Science" }),
      });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      await expect(service.getStudyAreaById("a1")).resolves.toEqual({ id: "a1", name: "Computer Science" });
    });
  });

  describe("createStudyArea", () => {
    it("rejects a duplicate name", async () => {
      const studyArea = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "existing" }) });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      await expect(service.createStudyArea({ name: "Computer Science" })).rejects.toThrow(
        'Study area "Computer Science" already exists'
      );
    });

    it("creates a new study area", async () => {
      const studyArea = mockModel({
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: "a1", name: "Computer Science" }),
      });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      const result = await service.createStudyArea({ name: "Computer Science" });

      expect(result).toEqual({ id: "a1", name: "Computer Science" });
      expect(studyArea.create).toHaveBeenCalledWith(expect.objectContaining({ data: { name: "Computer Science" } }));
    });
  });

  describe("updateStudyArea", () => {
    it("throws when the study area doesn't exist", async () => {
      const studyArea = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      await expect(service.updateStudyArea("missing", { name: "Physics" })).rejects.toThrow(
        "Study area not found"
      );
    });

    it("rejects renaming to a name that clashes with another study area", async () => {
      const studyArea = mockModel({
        findUnique: jest
          .fn()
          .mockResolvedValueOnce({ id: "a1", name: "Computer Science" })
          .mockResolvedValueOnce({ id: "a2", name: "Physics" }),
      });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      await expect(service.updateStudyArea("a1", { name: "Physics" })).rejects.toThrow(
        'Study area "Physics" already exists'
      );
    });

    it("updates the study area when there's no name clash", async () => {
      const studyArea = mockModel({
        findUnique: jest.fn().mockResolvedValueOnce({ id: "a1", name: "Computer Science" }).mockResolvedValueOnce(null),
        update: jest.fn().mockResolvedValue({ id: "a1", name: "Physics" }),
      });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      const result = await service.updateStudyArea("a1", { name: "Physics" });

      expect(result).toEqual({ id: "a1", name: "Physics" });
    });
  });

  describe("findOrCreateStudyArea", () => {
    it("returns the existing study area case-insensitively instead of creating a duplicate", async () => {
      const studyArea = mockModel({
        findFirst: jest.fn().mockResolvedValue({ id: "a1", name: "Computer Science" }),
        create: jest.fn(),
      });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      const result = await service.findOrCreateStudyArea({ name: "computer science" });

      expect(result).toEqual({ id: "a1", name: "Computer Science" });
      expect(studyArea.create).not.toHaveBeenCalled();
    });

    it("creates a new study area, trimming the name", async () => {
      const studyArea = mockModel({
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: "a2", name: "Astrophysics" }),
      });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      const result = await service.findOrCreateStudyArea({ name: "  Astrophysics  " });

      expect(studyArea.create).toHaveBeenCalledWith(expect.objectContaining({ data: { name: "Astrophysics" } }));
      expect(result).toEqual({ id: "a2", name: "Astrophysics" });
    });
  });

  describe("deleteStudyArea", () => {
    it("throws when the study area doesn't exist", async () => {
      const studyArea = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      await expect(service.deleteStudyArea("missing")).rejects.toThrow("Study area not found");
    });

    it("deletes an existing study area", async () => {
      const studyArea = mockModel({
        findUnique: jest.fn().mockResolvedValue({ id: "a1" }),
        delete: jest.fn().mockResolvedValue({ id: "a1" }),
      });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      await service.deleteStudyArea("a1");

      expect(studyArea.delete).toHaveBeenCalledWith({ where: { id: "a1" } });
    });
  });

  describe("seedStudyAreas", () => {
    it("bulk-creates the default catalog, skipping duplicates", async () => {
      const studyArea = mockModel({ createMany: jest.fn().mockResolvedValue({ count: 18 }) });
      const service = new StudyAreasService(createMockPrismaService({ studyArea }));

      const result = await service.seedStudyAreas();

      expect(result).toEqual({ seeded: 18 });
      expect(studyArea.createMany).toHaveBeenCalledWith(expect.objectContaining({ skipDuplicates: true }));
    });
  });
});
