import { NotesService } from "../notes.service";
import { SummariesService } from "../../summaries/summaries.service";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

function buildNote(overrides: Record<string, unknown> = {}) {
  return {
    id: "note-1",
    title: "React basics",
    content: "Hooks, props, state",
    summary: null,
    tags: ["react"],
    isPublic: false,
    authorId: "user-1",
    createdAt: new Date("2026-01-01"),
    updatedAt: new Date("2026-01-01"),
    author: { id: "user-1", name: "Author", email: "a@bedfordshire.ac.uk", avatarUrl: null },
    photos: [],
    ...overrides,
  };
}

function makeSummariesService(overrides: Partial<SummariesService> = {}) {
  return {
    summarize: jest.fn().mockResolvedValue("a short summary"),
    ...overrides,
  } as unknown as SummariesService;
}

describe("NotesService.getMyNotes", () => {
  it("paginates the caller's own notes and returns meta", async () => {
    const note = mockModel({
      findMany: jest.fn().mockResolvedValue([buildNote()]),
      count: jest.fn().mockResolvedValue(1),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    const result = await service.getMyNotes("user-1", {
      page: 1,
      limit: 10,
    } as never);

    expect(result.notes).toHaveLength(1);
    expect(result.meta).toEqual({ total: 1, page: 1, limit: 10, totalPages: 1 });
    expect(note.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ authorId: "user-1" }) })
    );
  });
});

describe("NotesService.getPublicNotes", () => {
  it("ranks notes with tags matching the caller's skills/study areas first", async () => {
    const matchingNote = buildNote({ id: "note-match", tags: ["react"] });
    const otherNote = buildNote({ id: "note-other", tags: ["cooking"] });
    const note = mockModel({
      findMany: jest.fn().mockResolvedValue([otherNote, matchingNote]),
    });
    const profile = mockModel({
      findUnique: jest.fn().mockResolvedValue({
        skills: [{ skill: { name: "React" } }],
        studyAreas: [],
      }),
    });
    const skill = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const studyArea = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const prisma = createMockPrismaService({ note, profile, skill, studyArea });
    const service = new NotesService(prisma, makeSummariesService());

    const result = await service.getPublicNotes("user-1", { page: 1, limit: 10 } as never);

    expect(result.notes.map((n: { id: string }) => n.id)).toEqual(["note-match", "note-other"]);
    expect(result.meta.total).toBe(2);
  });

  it("pulls in catalog terms matching the search string when searching", async () => {
    const note = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const profile = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const skill = mockModel({
      findMany: jest.fn().mockResolvedValue([{ id: "s1", name: "React" }]),
    });
    const studyArea = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const prisma = createMockPrismaService({ note, profile, skill, studyArea });
    const service = new NotesService(prisma, makeSummariesService());

    await service.getPublicNotes("user-1", { search: "react", page: 1, limit: 10 } as never);

    expect(note.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: expect.arrayContaining([{ tags: { hasSome: ["React"] } }]),
        }),
      })
    );
  });
});

describe("NotesService.getNoteById", () => {
  it("throws 404 when the note doesn't exist", async () => {
    const note = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(service.getNoteById("missing", "user-1")).rejects.toMatchObject({
      statusCode: 404,
    });
  });

  it("throws 403 when a private note is fetched by someone other than the author", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ isPublic: false })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(service.getNoteById("note-1", "someone-else")).rejects.toMatchObject({
      statusCode: 403,
    });
  });

  it("returns a public note for a non-author", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ isPublic: true })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    const result = await service.getNoteById("note-1", "someone-else");
    expect(result.id).toBe("note-1");
  });

  it("returns a private note for its author", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ isPublic: false, authorId: "user-1" })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    const result = await service.getNoteById("note-1", "user-1");
    expect(result.id).toBe("note-1");
  });
});

describe("NotesService.createNote", () => {
  it("creates a note owned by the caller", async () => {
    const note = mockModel({ create: jest.fn().mockResolvedValue(buildNote()) });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await service.createNote("user-1", {
      title: "React basics",
      content: "Hooks, props, state",
      tags: ["react"],
      isPublic: false,
    } as never);

    expect(note.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ authorId: "user-1" }) })
    );
  });
});

describe("NotesService.summarizeText", () => {
  it("delegates to SummariesService with the 'notes' task", async () => {
    const summariesService = makeSummariesService();
    const prisma = createMockPrismaService({});
    const service = new NotesService(prisma, summariesService);

    const result = await service.summarizeText("some content");

    expect(summariesService.summarize).toHaveBeenCalledWith("some content", "notes");
    expect(result).toBe("a short summary");
  });
});

describe("NotesService.updateNote", () => {
  it("throws 404 when the note doesn't exist", async () => {
    const note = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(service.updateNote("missing", "user-1", {} as never)).rejects.toMatchObject({
      statusCode: 404,
    });
  });

  it("throws 403 when a non-author tries to edit", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1" })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(
      service.updateNote("note-1", "someone-else", { title: "New" } as never)
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("updates only the fields provided", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1" })),
      update: jest.fn().mockResolvedValue(buildNote({ title: "Updated" })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await service.updateNote("note-1", "user-1", { title: "Updated" } as never);

    expect(note.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { title: "Updated" } })
    );
  });
});

describe("NotesService.generateSummary", () => {
  it("throws 404 when the note doesn't exist", async () => {
    const note = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(service.generateSummary("missing", "user-1")).rejects.toMatchObject({
      statusCode: 404,
    });
  });

  it("throws 403 when a non-author tries to summarize", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1" })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(service.generateSummary("note-1", "someone-else")).rejects.toMatchObject({
      statusCode: 403,
    });
  });

  it("summarizes the note's content and persists it", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1", content: "hooks" })),
      update: jest.fn().mockResolvedValue(buildNote({ summary: "a short summary" })),
    });
    const prisma = createMockPrismaService({ note });
    const summariesService = makeSummariesService();
    const service = new NotesService(prisma, summariesService);

    const result = await service.generateSummary("note-1", "user-1");

    expect(summariesService.summarize).toHaveBeenCalledWith("hooks", "notes");
    expect(note.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { summary: "a short summary" } })
    );
    expect(result.summary).toBe("a short summary");
  });
});

describe("NotesService.deleteNote", () => {
  it("throws 404 when the note doesn't exist", async () => {
    const note = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(service.deleteNote("missing", "user-1")).rejects.toMatchObject({
      statusCode: 404,
    });
  });

  it("throws 403 when a non-author tries to delete", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1" })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(service.deleteNote("note-1", "someone-else")).rejects.toMatchObject({
      statusCode: 403,
    });
  });

  it("deletes the note when called by its author", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1" })),
      delete: jest.fn().mockResolvedValue(undefined),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await service.deleteNote("note-1", "user-1");

    expect(note.delete).toHaveBeenCalledWith({ where: { id: "note-1" } });
  });
});

describe("NotesService.toggleVisibility", () => {
  it("throws 404 when the note doesn't exist", async () => {
    const note = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(service.toggleVisibility("missing", "user-1")).rejects.toMatchObject({
      statusCode: 404,
    });
  });

  it("throws 403 when a non-author tries to toggle visibility", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1" })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(service.toggleVisibility("note-1", "someone-else")).rejects.toMatchObject({
      statusCode: 403,
    });
  });

  it("flips isPublic from false to true", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1", isPublic: false })),
      update: jest.fn().mockResolvedValue(buildNote({ isPublic: true })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await service.toggleVisibility("note-1", "user-1");

    expect(note.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { isPublic: true } })
    );
  });
});

describe("NotesService.getNotesByUser", () => {
  it("returns only public notes when the requester isn't the author", async () => {
    const note = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await service.getNotesByUser("author-1", "someone-else");

    expect(note.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { authorId: "author-1", isPublic: true } })
    );
  });

  it("returns all notes (public and private) when the requester is the author", async () => {
    const note = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await service.getNotesByUser("author-1", "author-1");

    expect(note.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { authorId: "author-1" } })
    );
  });
});

describe("NotesService.getAllTags", () => {
  it("returns a deduplicated, sorted list of the caller's tags", async () => {
    const note = mockModel({
      findMany: jest.fn().mockResolvedValue([
        { tags: ["react", "css"] },
        { tags: ["react", "node"] },
      ]),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    const tags = await service.getAllTags("user-1");

    expect(tags).toEqual(["css", "node", "react"]);
  });
});

describe("NotesService.addPhotos", () => {
  it("throws 404 when the note doesn't exist", async () => {
    const note = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(
      service.addPhotos("missing", "user-1", [] as never)
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it("throws 403 when a non-author tries to add photos", async () => {
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1" })),
    });
    const prisma = createMockPrismaService({ note });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(
      service.addPhotos("note-1", "someone-else", [] as never)
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("creates a photo row per uploaded file and returns the refreshed note", async () => {
    const note = mockModel({
      findUnique: jest
        .fn()
        .mockResolvedValueOnce(buildNote({ authorId: "user-1" }))
        .mockResolvedValueOnce(buildNote({ authorId: "user-1", photos: [{ id: "p1" }] })),
    });
    const notePhoto = mockModel({ createMany: jest.fn().mockResolvedValue({ count: 1 }) });
    const prisma = createMockPrismaService({ note, notePhoto });
    const service = new NotesService(prisma, makeSummariesService());

    const files = [{ filename: "abc.jpg" }] as unknown as Express.Multer.File[];
    const result = await service.addPhotos("note-1", "user-1", files);

    expect(notePhoto.createMany).toHaveBeenCalledWith({
      data: [{ noteId: "note-1", url: "/uploads/notes/abc.jpg" }],
    });
    expect(result?.photos).toEqual([{ id: "p1" }]);
  });
});

describe("NotesService.deletePhoto", () => {
  it("throws 404 when the photo doesn't exist", async () => {
    const notePhoto = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const prisma = createMockPrismaService({ notePhoto });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(
      service.deletePhoto("note-1", "missing-photo", "user-1")
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it("throws 404 when the photo belongs to a different note", async () => {
    const notePhoto = mockModel({
      findUnique: jest.fn().mockResolvedValue({
        id: "photo-1",
        noteId: "other-note",
        url: "/uploads/notes/x.jpg",
        note: { authorId: "user-1" },
      }),
    });
    const prisma = createMockPrismaService({ notePhoto });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(
      service.deletePhoto("note-1", "photo-1", "user-1")
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it("throws 403 when a non-author tries to delete a photo", async () => {
    const notePhoto = mockModel({
      findUnique: jest.fn().mockResolvedValue({
        id: "photo-1",
        noteId: "note-1",
        url: "/uploads/notes/x.jpg",
        note: { authorId: "user-1" },
      }),
    });
    const prisma = createMockPrismaService({ notePhoto });
    const service = new NotesService(prisma, makeSummariesService());

    await expect(
      service.deletePhoto("note-1", "photo-1", "someone-else")
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("deletes the photo and returns the refreshed note", async () => {
    const notePhoto = mockModel({
      findUnique: jest.fn().mockResolvedValue({
        id: "photo-1",
        noteId: "note-1",
        url: "/uploads/notes/x.jpg",
        note: { authorId: "user-1" },
      }),
      delete: jest.fn().mockResolvedValue(undefined),
    });
    const note = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildNote({ authorId: "user-1", photos: [] })),
    });
    const prisma = createMockPrismaService({ notePhoto, note });
    const service = new NotesService(prisma, makeSummariesService());

    const result = await service.deletePhoto("note-1", "photo-1", "user-1");

    expect(notePhoto.delete).toHaveBeenCalledWith({ where: { id: "photo-1" } });
    expect(result?.photos).toEqual([]);
  });
});
