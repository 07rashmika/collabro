import { PrismaService } from "../../infrastructure/database/prisma.service";
import { AppError }      from "../../common/errors/app-error";
import {
  CreateSessionDto,
  UpdateSessionDto,
  SendMessageDto,
  SessionQueryDto,
  MessageQueryDto,
} from "./sessions.schema";

const sessionSelect = {
  id: true,
  title: true,
  type: true,
  status: true,
  summary: true,
  createdAt: true,
  updatedAt: true,
  creator: {
    select: { id: true, name: true, email: true },
  },
  participants: {
    select: {
      joinedAt: true,
      user: { select: { id: true, name: true, email: true } },
    },
  },
  _count: { select: { messages: true } },
} as const;

const messageSelect = {
  id: true,
  content: true,
  createdAt: true,
  updatedAt: true,
  sender: { select: { id: true, name: true, email: true } },
} as const;

export class SessionsService {
  constructor(private readonly prisma: PrismaService) {}

  async getMySessions(userId: string, query: SessionQueryDto) {
    const { status, type, page, limit } = query;
    const skip = (page - 1) * limit;

    const where = {
      participants: { some: { userId } },
      ...(status && { status }),
      ...(type   && { type }),
    };

    const [sessions, total] = await Promise.all([
      this.prisma.client.session.findMany({
        where,
        select:  sessionSelect,
        orderBy: { updatedAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.client.session.count({ where }),
    ]);

    return {
      sessions,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async getSessionById(sessionId: string, userId: string) {
    const session = await this.prisma.client.session.findUnique({
      where:  { id: sessionId },
      select: sessionSelect,
    });

    if (!session) {
      throw new AppError("Session not found", 404);
    }

    if (!session.participants.some((p) => p.user.id === userId)) {
      throw new AppError("You are not a participant of this session", 403);
    }

    return session;
  }

  async createSession(userId: string, dto: CreateSessionDto) {
    const users = await this.prisma.client.user.findMany({
      where:  { id: { in: dto.participantIds } },
      select: { id: true },
    });

    if (users.length !== dto.participantIds.length) {
      throw new AppError("One or more participant IDs are invalid", 400);
    }

    const allParticipantIds = [...new Set([userId, ...dto.participantIds])];

    return this.prisma.client.session.create({
      data: {
        title:     dto.title,
        type:      dto.type,
        createdBy: userId,
        participants: {
          create: allParticipantIds.map((id) => ({ userId: id })),
        },
      },
      select: sessionSelect,
    });
  }

  async updateSession(sessionId: string, userId: string, dto: UpdateSessionDto) {
    const session = await this.prisma.client.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.createdBy !== userId) {
      throw new AppError("Only the session creator can update it", 403);
    }

    return this.prisma.client.session.update({
      where:  { id: sessionId },
      data:   dto,
      select: sessionSelect,
    });
  }

  async closeSession(sessionId: string, userId: string) {
    const session = await this.prisma.client.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.createdBy !== userId) {
      throw new AppError("Only the session creator can close it", 403);
    }
    if (session.status === "CLOSED") {
      throw new AppError("Session is already closed", 409);
    }

    return this.prisma.client.session.update({
      where:  { id: sessionId },
      data:   { status: "CLOSED" },
      select: sessionSelect,
    });
  }

  async deleteSession(sessionId: string, userId: string) {
    const session = await this.prisma.client.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.createdBy !== userId) {
      throw new AppError("Only the session creator can delete it", 403);
    }

    await this.prisma.client.session.delete({ where: { id: sessionId } });
  }

  async addParticipant(sessionId: string, userId: string, participantId: string) {
    const session = await this.prisma.client.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.createdBy !== userId) {
      throw new AppError("Only the session creator can add participants", 403);
    }
    if (session.status === "CLOSED") {
      throw new AppError("Cannot add participants to a closed session", 409);
    }

    const participant = await this.prisma.client.user.findUnique({
      where: { id: participantId },
    });
    if (!participant) throw new AppError("User not found", 404);

    const existing = await this.prisma.client.sessionParticipant.findUnique({
      where: { sessionId_userId: { sessionId, userId: participantId } },
    });
    if (existing) throw new AppError("User is already a participant", 409);

    return this.prisma.client.sessionParticipant.create({
      data:   { sessionId, userId: participantId },
      select: {
        joinedAt: true,
        user: { select: { id: true, name: true, email: true } },
      },
    });
  }

  async removeParticipant(sessionId: string, userId: string, participantId: string) {
    const session = await this.prisma.client.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.createdBy !== userId) {
      throw new AppError("Only the session creator can remove participants", 403);
    }
    if (session.createdBy === participantId) {
      throw new AppError("Cannot remove the session creator", 400);
    }

    await this.prisma.client.sessionParticipant.delete({
      where: { sessionId_userId: { sessionId, userId: participantId } },
    });
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  async getMessages(sessionId: string, userId: string, query: MessageQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;

    const session = await this.prisma.client.session.findUnique({
      where:   { id: sessionId },
      include: { participants: true },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (!session.participants.some((p) => p.userId === userId)) {
      throw new AppError("You are not a participant of this session", 403);
    }

    const [messages, total] = await Promise.all([
      this.prisma.client.message.findMany({
        where:   { sessionId },
        select:  messageSelect,
        orderBy: { createdAt: "asc" },
        skip,
        take: limit,
      }),
      this.prisma.client.message.count({ where: { sessionId } }),
    ]);

    return {
      messages,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async sendMessage(sessionId: string, userId: string, dto: SendMessageDto) {
    const session = await this.prisma.client.session.findUnique({
      where:   { id: sessionId },
      include: { participants: true },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.status === "CLOSED") {
      throw new AppError("Cannot send messages to a closed session", 409);
    }
    if (!session.participants.some((p) => p.userId === userId)) {
      throw new AppError("You are not a participant of this session", 403);
    }

    // Create message and bump session updatedAt atomically
    const [message] = await this.prisma.client.$transaction([
      this.prisma.client.message.create({
        data:   { content: dto.content, sessionId, senderId: userId },
        select: messageSelect,
      }),
      this.prisma.client.session.update({
        where: { id: sessionId },
        data:  { updatedAt: new Date() },
      }),
    ]);

    return message;
  }

  async deleteMessage(messageId: string, userId: string) {
    const message = await this.prisma.client.message.findUnique({
      where: { id: messageId },
    });

    if (!message) throw new AppError("Message not found", 404);
    if (message.senderId !== userId) {
      throw new AppError("You can only delete your own messages", 403);
    }

    await this.prisma.client.message.delete({ where: { id: messageId } });
  }
}