import { PrismaService } from "../../infrastructure/database/prisma.service";
import { AppError }      from "../../common/errors/app-error";
import { CreateNoteDto, UpdateNoteDto, NoteQueryDto } from "./notes.schema";

const noteSelect = {
  id: true,
  title: true,
  content: true,
  tags: true,
  isPublic: true,
  createdAt: true,
  updatedAt: true,
  author: {
    select: { id: true, name: true, email: true },
  },
} as const;

export class NotesService {
  constructor(private readonly prisma: PrismaService) {}

  async getMyNotes(userId: string, query: NoteQueryDto) {
    const { search, tag, page, limit } = query;
    const skip = (page - 1) * limit;

    const where = {
      authorId: userId,
      ...(search && {
        OR: [
          { title:   { contains: search, mode: "insensitive" as const } },
          { content: { contains: search, mode: "insensitive" as const } },
        ],
      }),
      ...(tag && { tags: { has: tag } }),
    };

    const [notes, total] = await Promise.all([
      this.prisma.client.note.findMany({
        where,
        select: noteSelect,
        orderBy: { updatedAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.client.note.count({ where }),
    ]);

    return {
      notes,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async getPublicNotes(query: NoteQueryDto) {
    const { search, tag, page, limit } = query;
    const skip = (page - 1) * limit;

    const where = {
      isPublic: true,
      ...(search && {
        OR: [
          { title:   { contains: search, mode: "insensitive" as const } },
          { content: { contains: search, mode: "insensitive" as const } },
        ],
      }),
      ...(tag && { tags: { has: tag } }),
    };

    const [notes, total] = await Promise.all([
      this.prisma.client.note.findMany({
        where,
        select: noteSelect,
        orderBy: { updatedAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.client.note.count({ where }),
    ]);

    return {
      notes,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async getNoteById(noteId: string, userId: string) {
    const note = await this.prisma.client.note.findUnique({
      where:  { id: noteId },
      select: noteSelect,
    });

    if (!note) {
      throw new AppError("Note not found", 404);
    }

    if (!note.isPublic && note.author.id !== userId) {
      throw new AppError("You do not have access to this note", 403);
    }

    return note;
  }

  async createNote(userId: string, dto: CreateNoteDto) {
    return this.prisma.client.note.create({
      data: {
        title:    dto.title,
        content:  dto.content,
        tags:     dto.tags ?? [],
        isPublic: dto.isPublic,
        authorId: userId,
      },
      select: noteSelect,
    });
  }

  async updateNote(noteId: string, userId: string, dto: UpdateNoteDto) {
    const note = await this.prisma.client.note.findUnique({
      where: { id: noteId },
    });

    if (!note) {
      throw new AppError("Note not found", 404);
    }

    if (note.authorId !== userId) {
      throw new AppError("You can only edit your own notes", 403);
    }

    return this.prisma.client.note.update({
      where: { id: noteId },
      data: {
        ...(dto.title    !== undefined && { title:    dto.title }),
        ...(dto.content  !== undefined && { content:  dto.content }),
        ...(dto.tags     !== undefined && { tags:     dto.tags }),
        ...(dto.isPublic !== undefined && { isPublic: dto.isPublic }),
      },
      select: noteSelect,
    });
  }

  async deleteNote(noteId: string, userId: string) {
    const note = await this.prisma.client.note.findUnique({
      where: { id: noteId },
    });

    if (!note) {
      throw new AppError("Note not found", 404);
    }

    if (note.authorId !== userId) {
      throw new AppError("You can only delete your own notes", 403);
    }

    await this.prisma.client.note.delete({ where: { id: noteId } });
  }

  async toggleVisibility(noteId: string, userId: string) {
    const note = await this.prisma.client.note.findUnique({
      where: { id: noteId },
    });

    if (!note) {
      throw new AppError("Note not found", 404);
    }

    if (note.authorId !== userId) {
      throw new AppError("You can only update your own notes", 403);
    }

    return this.prisma.client.note.update({
      where:  { id: noteId },
      data:   { isPublic: !note.isPublic },
      select: noteSelect,
    });
  }

  async getNotesByUser(authorId: string, requesterId: string) {
    const where =
      authorId === requesterId
        ? { authorId }
        : { authorId, isPublic: true };

    return this.prisma.client.note.findMany({
      where,
      select:  noteSelect,
      orderBy: { updatedAt: "desc" },
    });
  }

  async getAllTags(userId: string) {
    const notes = await this.prisma.client.note.findMany({
      where:  { authorId: userId },
      select: { tags: true },
    });

    return [...new Set(notes.flatMap((n) => n.tags))].sort();
  }
}