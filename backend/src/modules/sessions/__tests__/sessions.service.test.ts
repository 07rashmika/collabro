import { SessionsService } from "../sessions.service";
import { sendPushToUser } from "../../notifications/push.service";
import { notifyUsers } from "../signaling/user-registry";
import { endRoom } from "../signaling/room-registry";
import { encryptSessionPassword } from "../../../common/utils/session-password.util";
import { ICE_SERVERS } from "../signaling/ice-servers.config";
import type { SessionQueryDto, PageQueryDto } from "../sessions.schema";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

jest.mock("../../notifications/push.service");
jest.mock("../signaling/user-registry");
jest.mock("../signaling/room-registry");

const mockedSendPush = sendPushToUser as jest.MockedFunction<typeof sendPushToUser>;
const mockedNotifyUsers = notifyUsers as jest.MockedFunction<typeof notifyUsers>;
const mockedEndRoom = endRoom as jest.MockedFunction<typeof endRoom>;

// summariesService/transcriptionClient are unused by the methods under test.
const dummySummaries = {} as never;
const dummyTranscription = {} as never;

function makeService(models: Record<string, unknown>) {
  const prisma = createMockPrismaService(models);
  return new SessionsService(prisma, dummySummaries, dummyTranscription);
}

describe("SessionsService.sendMessage", () => {
  afterEach(() => jest.clearAllMocks());

  const baseSession = {
    id: "session-1",
    title: "React Study Group",
    status: "ACTIVE",
    participants: [{ userId: "sender-1" }, { userId: "peer-1" }, { userId: "peer-2" }],
  };

  function mockPrisma(sessionOverrides: Record<string, unknown> = {}) {
    const message = mockModel({
      create: jest.fn().mockImplementation(({ data }: { data: { content: string; senderId: string } }) =>
        Promise.resolve({
          id: "msg-1",
          content: data.content,
          createdAt: new Date(),
          updatedAt: new Date(),
          sender: { id: data.senderId, name: "Alice", email: "alice@bedfordshire.ac.uk", avatarUrl: null },
        })
      ),
    });
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue({ ...baseSession, ...sessionOverrides }),
      update: jest.fn().mockResolvedValue({}),
    });
    const client = {
      message,
      session,
      $transaction: jest.fn((queries: Promise<unknown>[]) => Promise.all(queries)),
    };
    return { service: makeService(client), message, session };
  }

  it("rejects sending to a session that doesn't exist", async () => {
    const { service, session } = mockPrisma();
    (session.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(
      service.sendMessage("session-1", "sender-1", { content: "hi" })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it("rejects sending to a closed session", async () => {
    const { service } = mockPrisma({ status: "CLOSED" });

    await expect(
      service.sendMessage("session-1", "sender-1", { content: "hi" })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it("rejects a sender who isn't a participant", async () => {
    const { service } = mockPrisma();

    await expect(
      service.sendMessage("session-1", "outsider", { content: "hi" })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("persists the message and pushes every other participant, not the sender", async () => {
    const { service } = mockPrisma();

    await service.sendMessage("session-1", "sender-1", { content: "Anyone free at 5?" });

    expect(mockedSendPush).toHaveBeenCalledTimes(2);
    const pushedUserIds = mockedSendPush.mock.calls.map((call) => call[1]);
    expect(pushedUserIds.sort()).toEqual(["peer-1", "peer-2"]);
    for (const call of mockedSendPush.mock.calls) {
      expect(call[2]).toBe("messages");
      expect(call[3]).toMatchObject({
        title: "React Study Group",
        body: "Alice: Anyone free at 5?",
        data: { type: "NEW_MESSAGE", sessionId: "session-1" },
      });
    }
  });
});

describe("SessionsService.expireStaleSessions", () => {
  afterEach(() => jest.clearAllMocks());

  it("closes ACTIVE sessions past their type's TTL and notifies participants", async () => {
    const staleSession = {
      id: "session-old",
      participants: [{ userId: "u1" }, { userId: "u2" }],
    };
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([staleSession]),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    });
    const service = makeService({ session });

    await service.expireStaleSessions();

    expect(session.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ["session-old"] } },
      data: { status: "CLOSED" },
    });
    expect(mockedEndRoom).toHaveBeenCalledWith("session-old", expect.objectContaining({ type: expect.any(String) }));
    expect(mockedNotifyUsers).toHaveBeenCalledWith(["u1", "u2"], expect.anything());
  });

  it("does nothing when no sessions have expired", async () => {
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([]),
      updateMany: jest.fn(),
    });
    const service = makeService({ session });

    await service.expireStaleSessions();

    expect(session.updateMany).not.toHaveBeenCalled();
    expect(mockedEndRoom).not.toHaveBeenCalled();
  });
});

describe("SessionsService.addParticipant", () => {
  afterEach(() => jest.clearAllMocks());

  const activeSession = { id: "session-1", createdBy: "creator-1", status: "ACTIVE", title: "Algorithms 101" };

  function mockPrisma(overrides: {
    session?: Record<string, unknown> | null;
    userExists?: boolean;
    alreadyParticipant?: boolean;
  } = {}) {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(overrides.session === undefined ? activeSession : overrides.session),
    });
    const user = mockModel({
      findUnique: jest.fn().mockResolvedValue(overrides.userExists === false ? null : { id: "invitee-1" }),
    });
    const sessionParticipant = mockModel({
      findUnique: jest.fn().mockResolvedValue(overrides.alreadyParticipant ? { userId: "invitee-1" } : null),
      create: jest.fn().mockResolvedValue({ joinedAt: new Date(), user: { id: "invitee-1", name: "Invitee", email: "i@x.com" } }),
    });
    const notification = mockModel({ createMany: jest.fn().mockResolvedValue({ count: 1 }) });
    const client = { session, user, sessionParticipant, notification };
    return { service: makeService(client), ...client };
  }

  it("rejects when the caller isn't the session creator", async () => {
    const { service } = mockPrisma();
    await expect(
      service.addParticipant("session-1", "not-the-creator", "invitee-1")
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("rejects adding to a closed session", async () => {
    const { service } = mockPrisma({ session: { ...activeSession, status: "CLOSED" } });
    await expect(
      service.addParticipant("session-1", "creator-1", "invitee-1")
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it("rejects when the invitee doesn't exist", async () => {
    const { service } = mockPrisma({ userExists: false });
    await expect(
      service.addParticipant("session-1", "creator-1", "invitee-1")
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it("rejects re-adding an existing participant", async () => {
    const { service } = mockPrisma({ alreadyParticipant: true });
    await expect(
      service.addParticipant("session-1", "creator-1", "invitee-1")
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it("adds the participant and pushes a videoSessions-gated invite notification", async () => {
    const { service } = mockPrisma();

    await service.addParticipant("session-1", "creator-1", "invitee-1");

    expect(mockedSendPush).toHaveBeenCalledWith(
      expect.anything(),
      "invitee-1",
      "videoSessions",
      expect.objectContaining({ data: { type: "SESSION_INVITE", sessionId: "session-1" } })
    );
  });
});

// A raw `session` table row, as returned by a plain (unselected) findUnique —
// used by methods that only need scalar fields (createdBy/status/etc), never
// the nested creator/participants/tags shape.
function buildRawSession(overrides: Record<string, unknown> = {}) {
  return {
    id: "session-1",
    title: "React Study Group",
    type: "TEXT",
    status: "ACTIVE",
    summary: null,
    transcript: null,
    scheduledAt: null,
    joinCode: "ABC123",
    encryptedPassword: null,
    isPublic: false,
    createdAt: new Date("2026-01-01T00:00:00Z"),
    updatedAt: new Date("2026-01-01T00:00:00Z"),
    createdBy: "creator-1",
    ...overrides,
  };
}

// The `sessionSelect`-shaped session, as returned wherever the service reads
// or writes with `select: sessionSelect` and feeds the result through
// `toPublicSession`.
function buildFullSession(overrides: Record<string, unknown> = {}) {
  return {
    id: "session-1",
    title: "React Study Group",
    type: "TEXT",
    status: "ACTIVE",
    summary: null,
    transcript: null,
    scheduledAt: null,
    joinCode: "ABC123",
    encryptedPassword: null,
    isPublic: false,
    createdAt: new Date("2026-01-01T00:00:00Z"),
    updatedAt: new Date("2026-01-01T00:00:00Z"),
    creator: { id: "creator-1", name: "Creator", email: "creator@bedfordshire.ac.uk", avatarUrl: null },
    participants: [
      {
        joinedAt: new Date("2026-01-01T00:00:00Z"),
        user: { id: "creator-1", name: "Creator", email: "creator@bedfordshire.ac.uk", avatarUrl: null },
      },
    ],
    tags: [] as { skill: { id: string; name: string; category: string } }[],
    _count: { messages: 0 },
    ...overrides,
  };
}

describe("SessionsService.getMySessions", () => {
  afterEach(() => jest.clearAllMocks());

  const query = { status: undefined, type: undefined, upcoming: false, page: 1, limit: 10 } as SessionQueryDto;

  it("returns the caller's sessions with pagination meta and savedByMe flags", async () => {
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([buildFullSession({ id: "s1" }), buildFullSession({ id: "s2" })]),
      count: jest.fn().mockResolvedValue(2),
    });
    const savedSession = mockModel({ findMany: jest.fn().mockResolvedValue([{ sessionId: "s2" }]) });
    const service = makeService({ session, savedSession });

    const result = await service.getMySessions("user-1", query);

    expect(result.meta).toEqual({ total: 2, page: 1, limit: 10, totalPages: 1 });
    expect(result.sessions.map((s) => s.id)).toEqual(["s1", "s2"]);
    expect(result.sessions.find((s) => s.id === "s2")?.savedByMe).toBe(true);
    expect(result.sessions.find((s) => s.id === "s1")?.savedByMe).toBe(false);
  });

  it("applies the upcoming filter as a scheduledAt/status override, ordered by scheduledAt", async () => {
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
    });
    const savedSession = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const service = makeService({ session, savedSession });

    await service.getMySessions("user-1", { ...query, upcoming: true });

    expect(session.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ status: "ACTIVE", scheduledAt: { gte: expect.any(Date) } }),
        orderBy: { scheduledAt: "asc" },
      })
    );
  });
});

describe("SessionsService.getSessionById", () => {
  afterEach(() => jest.clearAllMocks());

  it("404s when the session doesn't exist", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = makeService({ session });
    await expect(service.getSessionById("s1", "user-1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("403s when the caller isn't a participant", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(buildFullSession({ participants: [] })) });
    const service = makeService({ session });
    await expect(service.getSessionById("s1", "user-1")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("returns the session with savedByMe for a participant", async () => {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(
        buildFullSession({
          participants: [
            { joinedAt: new Date(), user: { id: "user-1", name: "Me", email: "me@bedfordshire.ac.uk", avatarUrl: null } },
          ],
        })
      ),
    });
    const savedSession = mockModel({ findMany: jest.fn().mockResolvedValue([{ sessionId: "session-1" }]) });
    const service = makeService({ session, savedSession });

    const result = await service.getSessionById("session-1", "user-1");
    expect(result.savedByMe).toBe(true);
  });
});

describe("SessionsService.createSession", () => {
  afterEach(() => jest.clearAllMocks());

  const dto = {
    title: "Study Group",
    type: "TEXT" as const,
    participantIds: ["p1"],
    tagIds: ["skill-1"],
    isPublic: false,
  };

  function mockPrisma(overrides: { users?: unknown[]; skills?: unknown[] } = {}) {
    const user = mockModel({
      findMany: jest.fn().mockResolvedValue(overrides.users ?? [{ id: "p1" }]),
      findUnique: jest.fn().mockResolvedValue({ name: "Creator" }),
    });
    const skill = mockModel({
      findMany: jest.fn().mockResolvedValue(overrides.skills ?? [{ id: "skill-1" }]),
    });
    const session = mockModel({
      create: jest.fn().mockResolvedValue(buildFullSession({ id: "session-new", title: dto.title })),
    });
    const notification = mockModel({ createMany: jest.fn().mockResolvedValue({ count: 1 }) });
    const client = { user, skill, session, notification };
    return { service: makeService(client), ...client };
  }

  it("rejects when a participant ID doesn't exist", async () => {
    const { service } = mockPrisma({ users: [] });
    await expect(service.createSession("creator-1", { ...dto })).rejects.toMatchObject({ statusCode: 400 });
  });

  it("rejects when a tag/skill ID doesn't exist", async () => {
    const { service } = mockPrisma({ skills: [] });
    await expect(service.createSession("creator-1", { ...dto })).rejects.toMatchObject({ statusCode: 400 });
  });

  it("creates the session and notifies invited participants", async () => {
    const { service, notification } = mockPrisma();

    const result = await service.createSession("creator-1", { ...dto });

    expect(result.id).toBe("session-new");
    expect(notification.createMany).toHaveBeenCalledWith({
      data: [expect.objectContaining({ recipientId: "p1", type: "SESSION_INVITE" })],
    });
    expect(mockedNotifyUsers).toHaveBeenCalledWith(["p1"], expect.objectContaining({ type: "sessions-changed" }));
  });
});

describe("SessionsService.joinSessionByCode", () => {
  afterEach(() => jest.clearAllMocks());

  function mockPrisma(overrides: { session?: unknown } = {}) {
    const sessionRow = overrides.session === undefined ? buildFullSession() : overrides.session;
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(sessionRow) });
    const sessionParticipant = mockModel({ create: jest.fn().mockResolvedValue({}) });
    const savedSession = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const client = { session, sessionParticipant, savedSession };
    return { service: makeService(client), ...client };
  }

  it("404s for an invalid join code", async () => {
    const { service } = mockPrisma({ session: null });
    await expect(service.joinSessionByCode("user-2", { joinCode: "NOPE" })).rejects.toMatchObject({ statusCode: 404 });
  });

  it("409s when the session has ended", async () => {
    const { service } = mockPrisma({ session: buildFullSession({ status: "CLOSED" }) });
    await expect(service.joinSessionByCode("user-2", { joinCode: "ABC123" })).rejects.toMatchObject({ statusCode: 409 });
  });

  it("403s when a password is required but not supplied", async () => {
    const encrypted = encryptSessionPassword("letmein");
    const { service } = mockPrisma({ session: buildFullSession({ encryptedPassword: encrypted }) });
    await expect(service.joinSessionByCode("user-2", { joinCode: "ABC123" })).rejects.toMatchObject({ statusCode: 403 });
  });

  it("403s on an incorrect password", async () => {
    const encrypted = encryptSessionPassword("letmein");
    const { service } = mockPrisma({ session: buildFullSession({ encryptedPassword: encrypted }) });
    await expect(
      service.joinSessionByCode("user-2", { joinCode: "ABC123", password: "wrong" })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("joins with the correct password and adds a new participant", async () => {
    const encrypted = encryptSessionPassword("letmein");
    const { service, sessionParticipant } = mockPrisma({
      session: buildFullSession({ encryptedPassword: encrypted }),
    });

    await service.joinSessionByCode("user-2", { joinCode: "ABC123", password: "letmein" });

    expect(sessionParticipant.create).toHaveBeenCalledWith({
      data: { sessionId: "session-1", userId: "user-2" },
    });
    expect(mockedNotifyUsers).toHaveBeenCalled();
  });

  it("doesn't re-add an already-joined participant", async () => {
    const existingParticipant = {
      joinedAt: new Date(),
      user: { id: "user-2", name: "Bob", email: "bob@bedfordshire.ac.uk", avatarUrl: null },
    };
    const { service, sessionParticipant } = mockPrisma({
      session: buildFullSession({ participants: [existingParticipant] }),
    });

    await service.joinSessionByCode("user-2", { joinCode: "ABC123" });

    expect(sessionParticipant.create).not.toHaveBeenCalled();
  });
});

describe("SessionsService.updateSession", () => {
  afterEach(() => jest.clearAllMocks());

  function mockPrisma(rawSession: unknown = buildRawSession()) {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(rawSession),
      update: jest.fn().mockResolvedValue(buildFullSession({ title: "Updated title" })),
    });
    return { service: makeService({ session }), session };
  }

  it("404s when the session doesn't exist", async () => {
    const { service } = mockPrisma(null);
    await expect(service.updateSession("s1", "creator-1", { title: "New" })).rejects.toMatchObject({ statusCode: 404 });
  });

  it("403s for a non-creator", async () => {
    const { service } = mockPrisma();
    await expect(
      service.updateSession("session-1", "someone-else", { title: "New" })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("updates the session for its creator", async () => {
    const { service, session } = mockPrisma();
    const result = await service.updateSession("session-1", "creator-1", { title: "Updated title" });
    expect(session.update).toHaveBeenCalledWith({
      where: { id: "session-1" },
      data: { title: "Updated title" },
      select: expect.anything(),
    });
    expect(result.title).toBe("Updated title");
  });
});

describe("SessionsService.closeSession", () => {
  afterEach(() => jest.clearAllMocks());

  function mockPrisma(
    rawSession: unknown = buildRawSession({ participants: [{ userId: "creator-1" }, { userId: "peer-1" }] })
  ) {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(rawSession),
      update: jest.fn().mockResolvedValue(buildFullSession({ status: "CLOSED" })),
    });
    return { service: makeService({ session }) };
  }

  it("404s when the session doesn't exist", async () => {
    const { service } = mockPrisma(null);
    await expect(service.closeSession("s1", "creator-1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("403s for a non-creator", async () => {
    const { service } = mockPrisma();
    await expect(service.closeSession("session-1", "not-creator")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("409s when already closed", async () => {
    const { service } = mockPrisma(buildRawSession({ status: "CLOSED", participants: [{ userId: "creator-1" }] }));
    await expect(service.closeSession("session-1", "creator-1")).rejects.toMatchObject({ statusCode: 409 });
  });

  it("closes the session, ends the room, and notifies participants", async () => {
    const { service } = mockPrisma();
    const result = await service.closeSession("session-1", "creator-1");
    expect(result.status).toBe("CLOSED");
    expect(mockedEndRoom).toHaveBeenCalledWith("session-1", expect.anything());
    expect(mockedNotifyUsers).toHaveBeenCalledWith(["creator-1", "peer-1"], expect.anything());
  });
});

describe("SessionsService.deleteSession", () => {
  afterEach(() => jest.clearAllMocks());

  function mockPrisma(rawSession: unknown = buildRawSession()) {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(rawSession),
      delete: jest.fn().mockResolvedValue({}),
    });
    return { service: makeService({ session }), session };
  }

  it("404s when the session doesn't exist", async () => {
    const { service } = mockPrisma(null);
    await expect(service.deleteSession("s1", "creator-1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("403s for a non-creator", async () => {
    const { service } = mockPrisma();
    await expect(service.deleteSession("session-1", "not-creator")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("deletes the session for its creator", async () => {
    const { service, session } = mockPrisma();
    await service.deleteSession("session-1", "creator-1");
    expect(session.delete).toHaveBeenCalledWith({ where: { id: "session-1" } });
  });
});

describe("SessionsService.getSessionPassword", () => {
  afterEach(() => jest.clearAllMocks());

  function mockPrisma(rawSession: unknown = buildRawSession()) {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(rawSession) });
    return { service: makeService({ session }) };
  }

  it("404s when the session doesn't exist", async () => {
    const { service } = mockPrisma(null);
    await expect(service.getSessionPassword("s1", "creator-1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("403s for a non-creator", async () => {
    const { service } = mockPrisma();
    await expect(service.getSessionPassword("session-1", "not-creator")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("returns null when the session has no password", async () => {
    const { service } = mockPrisma();
    const result = await service.getSessionPassword("session-1", "creator-1");
    expect(result).toEqual({ password: null });
  });

  it("decrypts and returns the plaintext password for the creator", async () => {
    const encrypted = encryptSessionPassword("letmein");
    const { service } = mockPrisma(buildRawSession({ encryptedPassword: encrypted }));
    const result = await service.getSessionPassword("session-1", "creator-1");
    expect(result).toEqual({ password: "letmein" });
  });
});

describe("SessionsService.discoverPublicSessions", () => {
  afterEach(() => jest.clearAllMocks());

  function mockPrisma(
    overrides: {
      mySkills?: string[];
      connections?: { requesterId: string; addresseeId: string }[];
      matches?: unknown[];
    } = {}
  ) {
    const profile = mockModel({
      findUnique: jest.fn().mockResolvedValue({
        skills: (overrides.mySkills ?? []).map((skillId) => ({ skillId })),
      }),
    });
    const connection = mockModel({
      findMany: jest.fn().mockResolvedValue(overrides.connections ?? []),
    });
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue(overrides.matches ?? []),
    });
    const savedSession = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const skill = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const studyArea = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const client = { profile, connection, session, savedSession, skill, studyArea };
    return { service: makeService(client), ...client };
  }

  const query = { search: undefined, page: 1, limit: 10 } as PageQueryDto;

  it("returns nothing when the caller has no skills and no connections and didn't search", async () => {
    const { service } = mockPrisma();
    const result = await service.discoverPublicSessions("user-1", query);
    expect(result).toEqual({ sessions: [], meta: { total: 0, page: 1, limit: 10, totalPages: 0 } });
  });

  it("ranks a connection's session above a purely skill-matched one", async () => {
    const skillMatch = buildFullSession({
      id: "skill-match",
      creator: { id: "stranger-1", name: "Stranger", email: "s@bedfordshire.ac.uk", avatarUrl: null },
      tags: [{ skill: { id: "skill-1", name: "React", category: "Frontend" } }],
    });
    const connectionMatch = buildFullSession({
      id: "connection-match",
      creator: { id: "friend-1", name: "Friend", email: "f@bedfordshire.ac.uk", avatarUrl: null },
      tags: [],
    });
    const { service } = mockPrisma({
      mySkills: ["skill-1"],
      connections: [{ requesterId: "user-1", addresseeId: "friend-1" }],
      matches: [skillMatch, connectionMatch],
    });

    const result = await service.discoverPublicSessions("user-1", query);

    expect(result.sessions.map((s) => s.id)).toEqual(["connection-match", "skill-match"]);
  });

  it("falls back to a title/skill-tag search, ignoring the skill-overlap gate", async () => {
    const found = buildFullSession({ id: "found" });
    const { service, session } = mockPrisma({ matches: [found] });

    const result = await service.discoverPublicSessions("user-1", { ...query, search: "react" });

    expect(session.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: expect.arrayContaining([{ title: { contains: "react", mode: "insensitive" } }]),
        }),
      })
    );
    expect(result.sessions.map((s) => s.id)).toEqual(["found"]);
  });
});

describe("SessionsService.getPublicSessionsByUser", () => {
  afterEach(() => jest.clearAllMocks());

  it("returns an author's public, active sessions", async () => {
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([buildFullSession({ id: "s1" })]),
    });
    const savedSession = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const service = makeService({ session, savedSession });

    const result = await service.getPublicSessionsByUser("author-1", "viewer-1");

    expect(session.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { createdBy: "author-1", isPublic: true, status: "ACTIVE" } })
    );
    expect(result).toHaveLength(1);
  });
});

describe("SessionsService.saveSession", () => {
  afterEach(() => jest.clearAllMocks());

  it("404s when the session doesn't exist", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = makeService({ session });
    await expect(service.saveSession("user-1", "s1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("upserts a bookmark for an existing session", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(buildRawSession()) });
    const savedSession = mockModel({ upsert: jest.fn().mockResolvedValue({}) });
    const service = makeService({ session, savedSession });

    await service.saveSession("user-1", "session-1");

    expect(savedSession.upsert).toHaveBeenCalledWith({
      where: { userId_sessionId: { userId: "user-1", sessionId: "session-1" } },
      create: { userId: "user-1", sessionId: "session-1" },
      update: {},
    });
  });
});

describe("SessionsService.unsaveSession", () => {
  afterEach(() => jest.clearAllMocks());

  it("removes the bookmark", async () => {
    const savedSession = mockModel({ deleteMany: jest.fn().mockResolvedValue({ count: 1 }) });
    const service = makeService({ savedSession });

    await service.unsaveSession("user-1", "session-1");

    expect(savedSession.deleteMany).toHaveBeenCalledWith({ where: { userId: "user-1", sessionId: "session-1" } });
  });
});

describe("SessionsService.getSavedSessions", () => {
  afterEach(() => jest.clearAllMocks());

  it("returns the caller's bookmarked sessions, always with savedByMe true", async () => {
    const session = mockModel({
      findMany: jest.fn().mockResolvedValue([buildFullSession({ id: "s1" })]),
      count: jest.fn().mockResolvedValue(1),
    });
    const service = makeService({ session });

    const result = await service.getSavedSessions("user-1", { search: undefined, page: 1, limit: 10 } as PageQueryDto);

    expect(result.sessions[0]?.savedByMe).toBe(true);
    expect(result.meta).toEqual({ total: 1, page: 1, limit: 10, totalPages: 1 });
  });
});

describe("SessionsService.removeParticipant", () => {
  afterEach(() => jest.clearAllMocks());

  function mockPrisma(overrides: { session?: unknown; remaining?: number } = {}) {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(overrides.session === undefined ? buildRawSession() : overrides.session),
      update: jest.fn().mockResolvedValue({}),
    });
    const sessionParticipant = mockModel({
      delete: jest.fn().mockResolvedValue({}),
      count: jest.fn().mockResolvedValue(overrides.remaining ?? 2),
    });
    const client = { session, sessionParticipant };
    return { service: makeService(client), ...client };
  }

  it("404s when the session doesn't exist", async () => {
    const { service } = mockPrisma({ session: null });
    await expect(service.removeParticipant("s1", "creator-1", "peer-1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("403s for a non-creator", async () => {
    const { service } = mockPrisma();
    await expect(
      service.removeParticipant("session-1", "not-creator", "peer-1")
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  it("400s when trying to remove the creator", async () => {
    const { service } = mockPrisma();
    await expect(
      service.removeParticipant("session-1", "creator-1", "creator-1")
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it("removes the participant without closing when others remain", async () => {
    const { service, session } = mockPrisma({ remaining: 2 });
    await service.removeParticipant("session-1", "creator-1", "peer-1");
    expect(mockedNotifyUsers).toHaveBeenCalledWith(["peer-1"], expect.anything());
    expect(session.update).not.toHaveBeenCalled();
  });

  it("auto-closes the session once only the creator remains", async () => {
    const { service, session } = mockPrisma({ remaining: 1 });
    await service.removeParticipant("session-1", "creator-1", "peer-1");
    expect(session.update).toHaveBeenCalledWith({ where: { id: "session-1" }, data: { status: "CLOSED" } });
    expect(mockedEndRoom).toHaveBeenCalledWith("session-1", expect.anything());
    expect(mockedNotifyUsers).toHaveBeenCalledWith(["creator-1"], expect.anything());
  });
});

describe("SessionsService.getMessages", () => {
  afterEach(() => jest.clearAllMocks());

  const sessionWithParticipants = buildRawSession({ participants: [{ userId: "user-1" }] });

  it("404s when the session doesn't exist", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = makeService({ session });
    await expect(service.getMessages("s1", "user-1", { page: 1, limit: 20 })).rejects.toMatchObject({
      statusCode: 404,
    });
  });

  it("403s for a non-participant", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(sessionWithParticipants) });
    const service = makeService({ session });
    await expect(service.getMessages("session-1", "outsider", { page: 1, limit: 20 })).rejects.toMatchObject({
      statusCode: 403,
    });
  });

  it("returns paginated messages for a participant", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(sessionWithParticipants) });
    const message = mockModel({
      findMany: jest.fn().mockResolvedValue([{ id: "m1", content: "hi" }]),
      count: jest.fn().mockResolvedValue(1),
    });
    const service = makeService({ session, message });

    const result = await service.getMessages("session-1", "user-1", { page: 1, limit: 20 });

    expect(result.messages).toHaveLength(1);
    expect(result.meta).toEqual({ total: 1, page: 1, limit: 20, totalPages: 1 });
  });
});

describe("SessionsService.deleteMessage", () => {
  afterEach(() => jest.clearAllMocks());

  it("404s when the message doesn't exist", async () => {
    const message = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const service = makeService({ message });
    await expect(service.deleteMessage("m1", "user-1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("403s when deleting someone else's message", async () => {
    const message = mockModel({ findUnique: jest.fn().mockResolvedValue({ id: "m1", senderId: "someone-else" }) });
    const service = makeService({ message });
    await expect(service.deleteMessage("m1", "user-1")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("deletes the caller's own message", async () => {
    const message = mockModel({
      findUnique: jest.fn().mockResolvedValue({ id: "m1", senderId: "user-1" }),
      delete: jest.fn().mockResolvedValue({}),
    });
    const service = makeService({ message });

    await service.deleteMessage("m1", "user-1");

    expect(message.delete).toHaveBeenCalledWith({ where: { id: "m1" } });
  });
});

describe("SessionsService.generateSummary", () => {
  afterEach(() => jest.clearAllMocks());

  function makeServiceWithSummaries(client: Record<string, unknown>, summarize = jest.fn()) {
    const prisma = createMockPrismaService(client);
    return { service: new SessionsService(prisma, { summarize } as never, dummyTranscription), summarize };
  }

  const participant = {
    joinedAt: new Date(),
    user: { id: "user-1", name: "Me", email: "me@bedfordshire.ac.uk", avatarUrl: null },
  };

  it("404s when the session doesn't exist", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const { service } = makeServiceWithSummaries({ session });
    await expect(service.generateSummary("s1", "user-1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("403s for a non-participant", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(buildFullSession({ participants: [] })) });
    const { service } = makeServiceWithSummaries({ session });
    await expect(service.generateSummary("session-1", "user-1")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("409s for a VIDEO session with no messages and no summary yet (still processing)", async () => {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(
        buildFullSession({ type: "VIDEO", summary: null, participants: [participant] })
      ),
    });
    const message = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const { service } = makeServiceWithSummaries({ session, message });
    await expect(service.generateSummary("session-1", "user-1")).rejects.toMatchObject({ statusCode: 409 });
  });

  it("returns the already-processed summary for a VIDEO session with no chat but a saved summary", async () => {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(
        buildFullSession({ type: "VIDEO", summary: "Already summarized", participants: [participant] })
      ),
    });
    const message = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const savedSession = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const { service, summarize } = makeServiceWithSummaries({ session, message, savedSession });

    const result = await service.generateSummary("session-1", "user-1");

    expect(result.summary).toBe("Already summarized");
    expect(summarize).not.toHaveBeenCalled();
  });

  it("400s for a TEXT session with no messages", async () => {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildFullSession({ type: "TEXT", participants: [participant] })),
    });
    const message = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const { service } = makeServiceWithSummaries({ session, message });
    await expect(service.generateSummary("session-1", "user-1")).rejects.toMatchObject({ statusCode: 400 });
  });

  it("summarizes the transcript and saves it when messages exist", async () => {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildFullSession({ type: "TEXT", participants: [participant] })),
      update: jest.fn().mockResolvedValue(
        buildFullSession({ type: "TEXT", summary: "A summary", participants: [participant] })
      ),
    });
    const message = mockModel({
      findMany: jest.fn().mockResolvedValue([
        { id: "m1", content: "Hi", sender: { name: "Me" } },
        { id: "m2", content: "Hey", sender: { name: "Friend" } },
      ]),
    });
    const savedSession = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const { service, summarize } = makeServiceWithSummaries(
      { session, message, savedSession },
      jest.fn().mockResolvedValue("A summary")
    );

    const result = await service.generateSummary("session-1", "user-1");

    expect(summarize).toHaveBeenCalledWith("Me: Hi\nFriend: Hey", "dialogue");
    expect(result.summary).toBe("A summary");
  });
});

describe("SessionsService.processRecording", () => {
  afterEach(() => jest.clearAllMocks());

  function makeServiceWithTranscription(client: Record<string, unknown>, transcribe = jest.fn()) {
    const prisma = createMockPrismaService(client);
    return {
      service: new SessionsService(
        prisma,
        { summarize: jest.fn().mockResolvedValue("Recap") } as never,
        { transcribe } as never
      ),
      transcribe,
    };
  }

  const files = [
    { path: "/tmp/track1.webm", mimetype: "audio/webm", size: 100 },
  ] as unknown as Express.Multer.File[];
  const trackMeta = [{ label: "Alice", startedAt: "2026-01-01T00:00:00.000Z" }];

  it("404s when the session doesn't exist", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(null) });
    const { service } = makeServiceWithTranscription({ session });
    await expect(service.processRecording("s1", "creator-1", files, trackMeta)).rejects.toMatchObject({
      statusCode: 404,
    });
  });

  it("403s for a non-creator", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(buildRawSession()) });
    const { service } = makeServiceWithTranscription({ session });
    await expect(service.processRecording("session-1", "not-creator", files, trackMeta)).rejects.toMatchObject({
      statusCode: 403,
    });
  });

  it("400s when the session isn't closed yet", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(buildRawSession({ status: "ACTIVE" })) });
    const { service } = makeServiceWithTranscription({ session });
    await expect(service.processRecording("session-1", "creator-1", files, trackMeta)).rejects.toMatchObject({
      statusCode: 400,
    });
  });

  it("400s when no speech is detected across all tracks", async () => {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(buildRawSession({ status: "CLOSED" })) });
    const { service } = makeServiceWithTranscription({ session }, jest.fn().mockResolvedValue([]));
    await expect(service.processRecording("session-1", "creator-1", files, trackMeta)).rejects.toMatchObject({
      statusCode: 400,
    });
  });

  it("transcribes, merges, summarizes, and saves the recording's transcript", async () => {
    const session = mockModel({
      findUnique: jest.fn().mockResolvedValue(buildRawSession({ status: "CLOSED" })),
      update: jest.fn().mockResolvedValue(buildFullSession({ transcript: "Alice: Hello", summary: "Recap" })),
    });
    const savedSession = mockModel({ findMany: jest.fn().mockResolvedValue([]) });
    const { service } = makeServiceWithTranscription(
      { session, savedSession },
      jest.fn().mockResolvedValue([{ start: 0, text: "Hello" }])
    );

    const result = await service.processRecording("session-1", "creator-1", files, trackMeta);

    expect(session.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: { transcript: "Alice: Hello", summary: "Recap" } })
    );
    expect(result.summary).toBe("Recap");
  });
});

describe("SessionsService.getIceServers", () => {
  afterEach(() => jest.clearAllMocks());

  function mockPrisma(
    rawSession: unknown = buildRawSession({ type: "VIDEO", participants: [{ userId: "user-1" }] })
  ) {
    const session = mockModel({ findUnique: jest.fn().mockResolvedValue(rawSession) });
    return { service: makeService({ session }) };
  }

  it("404s when the session doesn't exist", async () => {
    const { service } = mockPrisma(null);
    await expect(service.getIceServers("s1", "user-1")).rejects.toMatchObject({ statusCode: 404 });
  });

  it("400s for a TEXT session", async () => {
    const { service } = mockPrisma(buildRawSession({ type: "TEXT", participants: [{ userId: "user-1" }] }));
    await expect(service.getIceServers("session-1", "user-1")).rejects.toMatchObject({ statusCode: 400 });
  });

  it("409s for a closed session", async () => {
    const { service } = mockPrisma(
      buildRawSession({ type: "VIDEO", status: "CLOSED", participants: [{ userId: "user-1" }] })
    );
    await expect(service.getIceServers("session-1", "user-1")).rejects.toMatchObject({ statusCode: 409 });
  });

  it("403s for a non-participant", async () => {
    const { service } = mockPrisma(buildRawSession({ type: "VIDEO", participants: [] }));
    await expect(service.getIceServers("session-1", "user-1")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("returns the ICE server config for a participant of an active video session", async () => {
    const { service } = mockPrisma();
    const result = await service.getIceServers("session-1", "user-1");
    expect(result).toEqual({ iceServers: ICE_SERVERS });
  });
});
