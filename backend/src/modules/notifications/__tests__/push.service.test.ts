import { sendPushToUser } from "../push.service";
import { getFirebaseApp } from "../../../infrastructure/push/firebase-admin";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

jest.mock("../../../infrastructure/push/firebase-admin");

const mockedGetFirebaseApp = getFirebaseApp as jest.MockedFunction<typeof getFirebaseApp>;

const payload = { title: "New connection request", body: "Someone wants to connect" };

function makePrisma(opts: {
  user?: Record<string, unknown> | null;
  tokens?: { id: string; token: string }[];
}) {
  const user = mockModel({
    findUnique: jest.fn().mockResolvedValue(
      opts.user === undefined
        ? { notifyMessages: true, notifyConnections: true, notifyVideoSessions: true }
        : opts.user
    ),
  });
  const deviceToken = mockModel({
    findMany: jest.fn().mockResolvedValue(opts.tokens ?? []),
    deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
  });
  return { prisma: createMockPrismaService({ user, deviceToken }), user, deviceToken };
}

describe("sendPushToUser", () => {
  afterEach(() => jest.clearAllMocks());

  it("is a no-op when Firebase isn't configured", async () => {
    mockedGetFirebaseApp.mockReturnValue(null);
    const { prisma, user } = makePrisma({});

    await sendPushToUser(prisma, "user-1", "connections", payload);

    expect(user.findUnique).not.toHaveBeenCalled();
  });

  it("is a no-op when the target user no longer exists", async () => {
    const sendEachForMulticast = jest.fn();
    mockedGetFirebaseApp.mockReturnValue({ messaging: () => ({ sendEachForMulticast }) } as never);
    const { prisma } = makePrisma({ user: null });

    await sendPushToUser(prisma, "user-1", "connections", payload);

    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it.each([
    ["messages", "notifyMessages"],
    ["connections", "notifyConnections"],
    ["videoSessions", "notifyVideoSessions"],
  ] as const)(
    "skips sending when the user has %s notifications turned off",
    async (category, flag) => {
      const sendEachForMulticast = jest.fn();
      mockedGetFirebaseApp.mockReturnValue({ messaging: () => ({ sendEachForMulticast }) } as never);
      const { prisma, deviceToken } = makePrisma({
        user: { notifyMessages: true, notifyConnections: true, notifyVideoSessions: true, [flag]: false },
      });

      await sendPushToUser(prisma, "user-1", category, payload);

      expect(deviceToken.findMany).not.toHaveBeenCalled();
      expect(sendEachForMulticast).not.toHaveBeenCalled();
    }
  );

  it("is a no-op when the category is enabled but the user has no registered devices", async () => {
    const sendEachForMulticast = jest.fn();
    mockedGetFirebaseApp.mockReturnValue({ messaging: () => ({ sendEachForMulticast }) } as never);
    const { prisma } = makePrisma({ tokens: [] });

    await sendPushToUser(prisma, "user-1", "connections", payload);

    expect(sendEachForMulticast).not.toHaveBeenCalled();
  });

  it("sends to every registered device with the given title/body/data", async () => {
    const sendEachForMulticast = jest.fn().mockResolvedValue({
      responses: [{ success: true }, { success: true }],
    });
    mockedGetFirebaseApp.mockReturnValue({ messaging: () => ({ sendEachForMulticast }) } as never);
    const { prisma } = makePrisma({
      tokens: [
        { id: "dt-1", token: "token-a" },
        { id: "dt-2", token: "token-b" },
      ],
    });

    await sendPushToUser(prisma, "user-1", "connections", {
      title: "New connection request",
      body: "Jane wants to connect with you",
      data: { type: "CONNECTION_REQUEST", connectionId: "conn-1" },
    });

    expect(sendEachForMulticast).toHaveBeenCalledWith(
      expect.objectContaining({
        tokens: ["token-a", "token-b"],
        notification: { title: "New connection request", body: "Jane wants to connect with you" },
        data: { type: "CONNECTION_REQUEST", connectionId: "conn-1" },
        android: expect.objectContaining({
          priority: "high",
          notification: { channelId: "high_importance_channel" },
        }),
      })
    );
  });

  it("prunes device tokens FCM reports as no longer registered", async () => {
    const sendEachForMulticast = jest.fn().mockResolvedValue({
      responses: [
        { success: true },
        { success: false, error: { code: "messaging/registration-token-not-registered" } },
        { success: false, error: { code: "messaging/invalid-registration-token" } },
        { success: false, error: { code: "messaging/internal-error" } },
      ],
    });
    mockedGetFirebaseApp.mockReturnValue({ messaging: () => ({ sendEachForMulticast }) } as never);
    const { prisma, deviceToken } = makePrisma({
      tokens: [
        { id: "dt-ok", token: "token-ok" },
        { id: "dt-stale-1", token: "token-stale-1" },
        { id: "dt-stale-2", token: "token-stale-2" },
        { id: "dt-transient-error", token: "token-transient" },
      ],
    });

    await sendPushToUser(prisma, "user-1", "connections", payload);

    // Only the two dead-token error codes are pruned — a transient/unknown
    // FCM error must not delete a token that might still be valid.
    expect(deviceToken.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ["dt-stale-1", "dt-stale-2"] } },
    });
  });
});
