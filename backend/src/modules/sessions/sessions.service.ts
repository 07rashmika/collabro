import { PrismaService } from "../../infrastructure/database/prisma.service";
import { AppError }      from "../../common/errors/app-error";
import { ICE_SERVERS }   from "./signaling/ice-servers.config";
import { endRoom }       from "./signaling/room-registry";
import { notifyUsers }   from "./signaling/user-registry";
import { SignalingMessageType, NotificationMessageType } from "./signaling/signaling.types";
import { SummariesService } from "../summaries/summaries.service";
import {
  encryptSessionPassword,
  decryptSessionPassword,
} from "../../common/utils/session-password.util";
import {
  CreateSessionDto,
  UpdateSessionDto,
  SendMessageDto,
  SessionQueryDto,
  MessageQueryDto,
  JoinByCodeDto,
  PageQueryDto,
} from "./sessions.schema";

// Sessions auto-close once past their type's time limit, counted from
// whichever of scheduledAt/createdAt marks when the session actually starts
// (so a session scheduled for the future doesn't expire before it begins).
const SESSION_TTL_MS: Record<"VIDEO" | "TEXT", number> = {
  VIDEO: 2 * 60 * 60 * 1000,
  TEXT:  4 * 60 * 60 * 1000,
};

const sessionSelect = {
  id: true,
  title: true,
  type: true,
  status: true,
  summary: true,
  scheduledAt: true,
  joinCode: true,
  encryptedPassword: true,
  isPublic: true,
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
  tags: {
    select: {
      skill: { select: { id: true, name: true, category: true } },
    },
  },
  _count: { select: { messages: true } },
} as const;

type SelectedSession = {
  type: "VIDEO" | "TEXT";
  scheduledAt: Date | null;
  createdAt: Date;
  encryptedPassword: string | null;
  joinCode: string;
  isPublic: boolean;
  creator: { id: string };
  tags: { skill: { id: string; name: string; category: string } }[];
};

/// Strips the encrypted password before a session ever leaves the service
/// layer (only `hasPassword` goes out — the ciphertext never does, and only
/// the creator can decrypt it via `getSessionPassword`), flattens tags down
/// to bare skills, hides the join code from non-creators unless the session
/// is public, and adds the derived `expiresAt` (never stored — computed from
/// type + scheduledAt/createdAt) so the client can display/enforce it.
function toPublicSession<T extends SelectedSession>(session: T, viewerId: string) {
  const { encryptedPassword, joinCode, tags, ...rest } = session;
  const isCreator = session.creator.id === viewerId;
  const anchor = session.scheduledAt ?? session.createdAt;
  return {
    ...rest,
    tags: tags.map((t) => t.skill),
    hasPassword: encryptedPassword !== null,
    joinCode: isCreator || session.isPublic ? joinCode : null,
    expiresAt: new Date(anchor.getTime() + SESSION_TTL_MS[session.type]),
  };
}

const messageSelect = {
  id: true,
  content: true,
  createdAt: true,
  updatedAt: true,
  sender: { select: { id: true, name: true, email: true } },
} as const;

export class SessionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly summariesService: SummariesService
  ) {}

  /// Which of `sessionIds` the user has bookmarked — batched into one query
  /// per list response instead of N.
  private async savedSessionIds(userId: string, sessionIds: string[]): Promise<Set<string>> {
    if (sessionIds.length === 0) return new Set();
    const rows = await this.prisma.client.savedSession.findMany({
      where:  { userId, sessionId: { in: sessionIds } },
      select: { sessionId: true },
    });
    return new Set(rows.map((r) => r.sessionId));
  }

  /// Auto-closes any ACTIVE session past its type's time limit (see
  /// SESSION_TTL_MS), the same way `closeSession` does manually — flips it
  /// to CLOSED and notifies any connected clients over the signaling socket
  /// so they get kicked out exactly like a manual end. Run on a timer from
  /// sessions.routes.ts rather than checked per-request, since expiry here
  /// is on the order of hours, not something that needs sub-request latency.
  async expireStaleSessions(): Promise<void> {
    const now = Date.now();
    const videoThreshold = new Date(now - SESSION_TTL_MS.VIDEO);
    const textThreshold  = new Date(now - SESSION_TTL_MS.TEXT);

    const expired = await this.prisma.client.session.findMany({
      where: {
        status: "ACTIVE",
        OR: [
          {
            type: "VIDEO",
            OR: [
              { scheduledAt: null, createdAt: { lt: videoThreshold } },
              { scheduledAt: { lt: videoThreshold } },
            ],
          },
          {
            type: "TEXT",
            OR: [
              { scheduledAt: null, createdAt: { lt: textThreshold } },
              { scheduledAt: { lt: textThreshold } },
            ],
          },
        ],
      },
      select: { id: true, participants: { select: { userId: true } } },
    });
    if (expired.length === 0) return;

    const ids = expired.map((s) => s.id);
    await this.prisma.client.session.updateMany({
      where: { id: { in: ids } },
      data:  { status: "CLOSED" },
    });
    for (const session of expired) {
      endRoom(session.id, { type: SignalingMessageType.SESSION_ENDED });
      notifyUsers(
        session.participants.map((p) => p.userId),
        { type: NotificationMessageType.SESSIONS_CHANGED }
      );
    }
  }

  async getMySessions(userId: string, query: SessionQueryDto) {
    const { status, type, upcoming, page, limit } = query;
    const skip = (page - 1) * limit;

    const where = {
      participants: { some: { userId } },
      ...(status && { status }),
      ...(type   && { type }),
      ...(upcoming && { scheduledAt: { gte: new Date() }, status: "ACTIVE" as const }),
    };

    const [sessions, total] = await Promise.all([
      this.prisma.client.session.findMany({
        where,
        select:  sessionSelect,
        orderBy: upcoming ? { scheduledAt: "asc" } : { updatedAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.client.session.count({ where }),
    ]);

    const saved = await this.savedSessionIds(userId, sessions.map((s) => s.id));
    return {
      sessions: sessions.map((s) => ({ ...toPublicSession(s, userId), savedByMe: saved.has(s.id) })),
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

    const saved = await this.savedSessionIds(userId, [session.id]);
    return { ...toPublicSession(session, userId), savedByMe: saved.has(session.id) };
  }

  async createSession(userId: string, dto: CreateSessionDto) {
    const [users, skills] = await Promise.all([
      this.prisma.client.user.findMany({
        where:  { id: { in: dto.participantIds } },
        select: { id: true },
      }),
      this.prisma.client.skill.findMany({
        where:  { id: { in: dto.tagIds } },
        select: { id: true },
      }),
    ]);

    if (users.length !== dto.participantIds.length) {
      throw new AppError("One or more participant IDs are invalid", 400);
    }
    if (skills.length !== dto.tagIds.length) {
      throw new AppError("One or more tag IDs are invalid", 400);
    }

    const allParticipantIds = [...new Set([userId, ...dto.participantIds])];
    const encryptedPassword = dto.password ? encryptSessionPassword(dto.password) : null;

    const session = await this.prisma.client.session.create({
      data: {
        title:       dto.title,
        type:        dto.type,
        createdBy:   userId,
        scheduledAt: dto.scheduledAt ? new Date(dto.scheduledAt) : null,
        encryptedPassword,
        isPublic:    dto.isPublic,
        participants: {
          create: allParticipantIds.map((id) => ({ userId: id })),
        },
        tags: {
          create: dto.tagIds.map((skillId) => ({ skillId })),
        },
      },
      select: sessionSelect,
    });

    // The creator already has this fresh state locally — only the invitees
    // need telling that a session just appeared for them.
    notifyUsers(dto.participantIds, { type: NotificationMessageType.SESSIONS_CHANGED });

    return { ...toPublicSession(session, userId), savedByMe: false };
  }

  async joinSessionByCode(userId: string, dto: JoinByCodeDto) {
    const session = await this.prisma.client.session.findUnique({
      where:  { joinCode: dto.joinCode },
      select: sessionSelect,
    });

    if (!session) throw new AppError("Invalid join code", 404);
    if (session.status === "CLOSED") {
      throw new AppError("This session has ended", 409);
    }

    if (session.encryptedPassword) {
      // 403, not 401 — the caller is authenticated, just not authorized for
      // this session yet. A 401 here would trip the API client's "access
      // token expired" refresh-and-retry interceptor into looping forever.
      if (!dto.password) {
        throw new AppError("This session requires a password", 403);
      }
      const valid = decryptSessionPassword(session.encryptedPassword) === dto.password;
      if (!valid) {
        throw new AppError("Incorrect password", 403);
      }
    }

    const alreadyParticipant = session.participants.some((p) => p.user.id === userId);
    if (!alreadyParticipant) {
      await this.prisma.client.sessionParticipant.create({
        data: { sessionId: session.id, userId },
      });
      // Let everyone already in the session know its participant list
      // changed (the joiner sees their own fresh state from this response).
      notifyUsers(
        session.participants.map((p) => p.user.id),
        { type: NotificationMessageType.SESSIONS_CHANGED }
      );
    }

    const joined = await this.prisma.client.session.findUnique({
      where:  { id: session.id },
      select: sessionSelect,
    });

    const saved = await this.savedSessionIds(userId, [session.id]);
    return { ...toPublicSession(joined!, userId), savedByMe: saved.has(session.id) };
  }

  async updateSession(sessionId: string, userId: string, dto: UpdateSessionDto) {
    const session = await this.prisma.client.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.createdBy !== userId) {
      throw new AppError("Only the session creator can update it", 403);
    }

    const updated = await this.prisma.client.session.update({
      where:  { id: sessionId },
      data:   dto,
      select: sessionSelect,
    });
    return { ...toPublicSession(updated, userId), savedByMe: false };
  }

  async closeSession(sessionId: string, userId: string) {
    const session = await this.prisma.client.session.findUnique({
      where:   { id: sessionId },
      include: { participants: true },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.createdBy !== userId) {
      throw new AppError("Only the session creator can close it", 403);
    }
    if (session.status === "CLOSED") {
      throw new AppError("Session is already closed", 409);
    }

    const closed = await this.prisma.client.session.update({
      where:  { id: sessionId },
      data:   { status: "CLOSED" },
      select: sessionSelect,
    });

    endRoom(sessionId, { type: SignalingMessageType.SESSION_ENDED });
    // Moves the session from "My Sessions" to "Ended" live for everyone,
    // not just whoever's actively connected to the session's room.
    notifyUsers(
      session.participants.map((p) => p.userId),
      { type: NotificationMessageType.SESSIONS_CHANGED }
    );
    return { ...toPublicSession(closed, userId), savedByMe: false };
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

  /// Owner-only — decrypts the session password back to plaintext for the
  /// "view password" action in the session info panel. Never exposed to
  /// anyone else; other participants only ever see `hasPassword`.
  async getSessionPassword(sessionId: string, userId: string) {
    const session = await this.prisma.client.session.findUnique({
      where: { id: sessionId },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.createdBy !== userId) {
      throw new AppError("Only the session creator can view the password", 403);
    }

    return {
      password: session.encryptedPassword
        ? decryptSessionPassword(session.encryptedPassword)
        : null,
    };
  }

  /// Public sessions the caller isn't already in, upcoming, ranked by how
  /// many of a session's skill tags overlap with the caller's own profile
  /// skills — the more relevant a session is to what the caller is
  /// learning, the earlier it surfaces, ahead of raw scheduling order. With
  /// no `search` a skill-match is also required to appear at all (the feed
  /// that surfaces on the Home tab's Upcoming Sessions); with a `search`
  /// term (Discovery tab) that gate is dropped in favor of a title search,
  /// so it works for callers with no skills on their profile, with skill
  /// overlap only affecting order.
  async discoverPublicSessions(userId: string, query: PageQueryDto) {
    const { search, page, limit } = query;
    const skip = (page - 1) * limit;

    const myProfile = await this.prisma.client.profile.findUnique({
      where:  { userId },
      select: { skills: { select: { skillId: true } } },
    });
    const mySkillIds = new Set(myProfile?.skills.map((s) => s.skillId) ?? []);

    const baseWhere = {
      isPublic:    true,
      status:      "ACTIVE" as const,
      scheduledAt: { gte: new Date() },
      createdBy:   { not: userId },
      participants: { none: { userId } },
    };

    let where: typeof baseWhere & Record<string, unknown> = baseWhere;

    if (search) {
      where = { ...baseWhere, title: { contains: search, mode: "insensitive" as const } };
    } else {
      if (mySkillIds.size === 0) {
        return { sessions: [], meta: { total: 0, page, limit, totalPages: 0 } };
      }

      where = { ...baseWhere, tags: { some: { skillId: { in: [...mySkillIds] } } } };
    }

    // Ranking needs the full matching set scored before it can be paged, so
    // this fetches everything the where-clause allows rather than a single
    // DB page — fine at this app's scale (mirrors MatchingService).
    const matches = await this.prisma.client.session.findMany({
      where,
      select:  sessionSelect,
      orderBy: { scheduledAt: "asc" },
    });

    const scored = matches
      .map((session) => ({
        session,
        score: session.tags.filter((t) => mySkillIds.has(t.skill.id)).length,
      }))
      .sort((a, b) => b.score - a.score);

    const total = scored.length;
    const sessions = scored.slice(skip, skip + limit).map((s) => s.session);

    const saved = await this.savedSessionIds(userId, sessions.map((s) => s.id));
    return {
      sessions: sessions.map((s) => ({ ...toPublicSession(s, userId), savedByMe: saved.has(s.id) })),
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async saveSession(userId: string, sessionId: string) {
    const session = await this.prisma.client.session.findUnique({
      where: { id: sessionId },
    });
    if (!session) throw new AppError("Session not found", 404);

    await this.prisma.client.savedSession.upsert({
      where:  { userId_sessionId: { userId, sessionId } },
      create: { userId, sessionId },
      update: {},
    });
  }

  async unsaveSession(userId: string, sessionId: string) {
    await this.prisma.client.savedSession.deleteMany({ where: { userId, sessionId } });
  }

  async getSavedSessions(userId: string, query: PageQueryDto) {
    const { page, limit } = query;
    const skip = (page - 1) * limit;
    const where = { savedBy: { some: { userId } } };

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
      sessions: sessions.map((s) => ({ ...toPublicSession(s, userId), savedByMe: true })),
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
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

    const created = await this.prisma.client.sessionParticipant.create({
      data:   { sessionId, userId: participantId },
      select: {
        joinedAt: true,
        user: { select: { id: true, name: true, email: true } },
      },
    });

    notifyUsers([participantId], { type: NotificationMessageType.SESSIONS_CHANGED });
    return created;
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
    notifyUsers([participantId], { type: NotificationMessageType.SESSIONS_CHANGED });

    // The creator can never remove themselves, so the count can only ever
    // bottom out at 1 (the creator, alone). Once no one else is left,
    // there's no one to have a session with — close it automatically.
    const remaining = await this.prisma.client.sessionParticipant.count({
      where: { sessionId },
    });
    if (remaining <= 1 && session.status !== "CLOSED") {
      await this.prisma.client.session.update({
        where: { id: sessionId },
        data:  { status: "CLOSED" },
      });
      endRoom(sessionId, { type: SignalingMessageType.SESSION_ENDED });
      notifyUsers([session.createdBy], { type: NotificationMessageType.SESSIONS_CHANGED });
    }
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

  /// Any participant (not just the creator) can request a recap — this is
  /// what backs both the "want a summary?" end-of-session prompt and the
  /// "Summary" button on ended sessions. Builds a transcript from the
  /// session's messages and hands it to the same fine-tuned summarizer Notes
  /// uses (see SummariesService / ml-service).
  async generateSummary(sessionId: string, userId: string) {
    const session = await this.prisma.client.session.findUnique({
      where:   { id: sessionId },
      include: { participants: true },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (!session.participants.some((p) => p.userId === userId)) {
      throw new AppError("You are not a participant of this session", 403);
    }

    const messages = await this.prisma.client.message.findMany({
      where:   { sessionId },
      select:  messageSelect,
      orderBy: { createdAt: "asc" },
    });
    if (messages.length === 0) {
      throw new AppError("No messages to summarize yet", 400);
    }

    const transcript = messages.map((m) => `${m.sender.name}: ${m.content}`).join("\n");
    const summary = await this.summariesService.summarize(transcript, "dialogue");

    const updated = await this.prisma.client.session.update({
      where:  { id: sessionId },
      data:   { summary },
      select: sessionSelect,
    });

    const saved = await this.savedSessionIds(userId, [sessionId]);
    return { ...toPublicSession(updated, userId), savedByMe: saved.has(sessionId) };
  }

  // ── Video calling (WebRTC ICE config) ───────────────────────────────────

  async getIceServers(sessionId: string, userId: string) {
    const session = await this.prisma.client.session.findUnique({
      where:   { id: sessionId },
      include: { participants: true },
    });

    if (!session) throw new AppError("Session not found", 404);
    if (session.type !== "VIDEO") {
      throw new AppError("This session does not support video calling", 400);
    }
    if (session.status === "CLOSED") {
      throw new AppError("Cannot join a closed session", 409);
    }
    if (!session.participants.some((p) => p.userId === userId)) {
      throw new AppError("You are not a participant of this session", 403);
    }

    return { iceServers: ICE_SERVERS };
  }
}