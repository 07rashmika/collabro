jest.mock("../../../../infrastructure/database/prisma.service", () => ({
  PrismaService: { getInstance: () => ({ client: {} }) },
}));
jest.mock("../../sessions.service");
jest.mock("../room-registry");

import { handleConnection, handleMessage } from "../signaling.gateway";
import { SessionsService } from "../../sessions.service";
import { SignalingMessageType } from "../signaling.types";
import { ConnectedClient, joinRoom, leaveRoom, getClient, broadcastToRoom, sendToUser } from "../room-registry";

const mockedJoinRoom = joinRoom as jest.MockedFunction<typeof joinRoom>;
const mockedLeaveRoom = leaveRoom as jest.MockedFunction<typeof leaveRoom>;
const mockedGetClient = getClient as jest.MockedFunction<typeof getClient>;
const mockedBroadcastToRoom = broadcastToRoom as jest.MockedFunction<typeof broadcastToRoom>;
const mockedSendToUser = sendToUser as jest.MockedFunction<typeof sendToUser>;

// The gateway module builds one SessionsService instance at import time; since
// jest.mock auto-mocks the class, every instance shares the same mocked
// prototype methods, so this is the same `sendMessage` the gateway calls.
const mockedSendMessage = SessionsService.prototype.sendMessage as jest.Mock;

function makeWs() {
  return { readyState: 1, OPEN: 1, send: jest.fn(), on: jest.fn() };
}

function makeClient(overrides: Partial<ConnectedClient> = {}): ConnectedClient {
  return {
    ws: makeWs() as unknown as ConnectedClient["ws"],
    userId: "user-1",
    name: "Alice",
    isMicMuted: false,
    isCameraOff: false,
    isScreenSharing: false,
    ...overrides,
  };
}

afterEach(() => jest.clearAllMocks());

describe("handleConnection", () => {
  it("sends a ROOM_SNAPSHOT and broadcasts PARTICIPANT_JOINED on a first-time join", () => {
    mockedGetClient.mockReturnValue(undefined);
    mockedJoinRoom.mockReturnValue([{ userId: "peer-1", name: "Bob", isMicMuted: false, isCameraOff: false, isScreenSharing: false }]);
    const client = makeClient();

    handleConnection(client.ws, "session-1", client);

    expect(client.ws.send).toHaveBeenCalledWith(
      JSON.stringify({
        type: SignalingMessageType.ROOM_SNAPSHOT,
        participants: [{ userId: "peer-1", name: "Bob", isMicMuted: false, isCameraOff: false, isScreenSharing: false }],
      })
    );
    expect(mockedBroadcastToRoom).toHaveBeenCalledWith("session-1", "user-1", {
      type: SignalingMessageType.PARTICIPANT_JOINED,
      participant: { userId: "user-1", name: "Alice", isMicMuted: false, isCameraOff: false, isScreenSharing: false },
    });
  });

  it("sends RECONNECTED_STATE instead when the user was already connected", () => {
    mockedGetClient.mockReturnValue(makeClient());
    mockedJoinRoom.mockReturnValue([]);
    const client = makeClient();

    handleConnection(client.ws, "session-1", client);

    expect(client.ws.send).toHaveBeenCalledWith(
      JSON.stringify({ type: SignalingMessageType.RECONNECTED_STATE, participants: [] })
    );
  });

  it("registers a close handler that leaves the room and broadcasts PARTICIPANT_LEFT", () => {
    mockedGetClient.mockReturnValue(undefined);
    mockedJoinRoom.mockReturnValue([]);
    const client = makeClient();

    handleConnection(client.ws, "session-1", client);

    const onMock = client.ws.on as jest.Mock;
    const closeHandler = onMock.mock.calls.find((call) => call[0] === "close")?.[1];
    expect(closeHandler).toBeDefined();

    closeHandler();

    expect(mockedLeaveRoom).toHaveBeenCalledWith("session-1", "user-1");
    expect(mockedBroadcastToRoom).toHaveBeenCalledWith("session-1", "user-1", {
      type: SignalingMessageType.PARTICIPANT_LEFT,
      userId: "user-1",
    });
  });
});

describe("handleMessage", () => {
  const client = () => makeClient();

  it("relays an OFFER to the target when delivered", async () => {
    mockedSendToUser.mockReturnValue(true);
    const c = client();

    await handleMessage("session-1", c, JSON.stringify({ type: SignalingMessageType.OFFER, targetUserId: "peer-1", sdp: "abc" }));

    expect(mockedSendToUser).toHaveBeenCalledWith("session-1", "peer-1", {
      type: SignalingMessageType.OFFER,
      targetUserId: "peer-1",
      sdp: "abc",
      fromUserId: "user-1",
    });
    expect(c.ws.send).not.toHaveBeenCalled();
  });

  it("sends an ERROR back to the sender when the ICE_CANDIDATE target isn't connected", async () => {
    mockedSendToUser.mockReturnValue(false);
    const c = client();

    await handleMessage(
      "session-1",
      c,
      JSON.stringify({ type: SignalingMessageType.ICE_CANDIDATE, targetUserId: "peer-1", candidate: "cand" })
    );

    expect(c.ws.send).toHaveBeenCalledWith(
      JSON.stringify({ type: SignalingMessageType.ERROR, message: "Target participant not connected" })
    );
  });

  it("relays an ANSWER the same way as an OFFER", async () => {
    mockedSendToUser.mockReturnValue(true);
    const c = client();

    await handleMessage("session-1", c, JSON.stringify({ type: SignalingMessageType.ANSWER, targetUserId: "peer-1", sdp: "xyz" }));

    expect(mockedSendToUser).toHaveBeenCalledWith(
      "session-1",
      "peer-1",
      expect.objectContaining({ type: SignalingMessageType.ANSWER, fromUserId: "user-1" })
    );
  });

  it("saves a chat message and broadcasts it to the whole room, including the sender", async () => {
    mockedSendMessage.mockResolvedValue({
      id: "msg-1",
      content: "hello",
      createdAt: new Date("2026-01-01T00:00:00Z"),
      sender: { id: "user-1", name: "Alice", avatarUrl: null },
    });
    const c = client();

    await handleMessage("session-1", c, JSON.stringify({ type: SignalingMessageType.CHAT_MESSAGE, content: "hello" }));

    expect(mockedSendMessage).toHaveBeenCalledWith("session-1", "user-1", { content: "hello" });
    expect(mockedBroadcastToRoom).toHaveBeenCalledWith(
      "session-1",
      "user-1",
      {
        type: SignalingMessageType.CHAT_MESSAGE,
        message: {
          id: "msg-1",
          sessionId: "session-1",
          senderId: "user-1",
          senderName: "Alice",
          senderAvatarUrl: null,
          content: "hello",
          createdAt: new Date("2026-01-01T00:00:00Z"),
        },
      },
      { includeSender: true }
    );
  });

  it("updates and broadcasts SCREEN_SHARE_STATE, mutating the in-memory client", async () => {
    const c = client();

    await handleMessage(
      "session-1",
      c,
      JSON.stringify({ type: SignalingMessageType.SCREEN_SHARE_STATE, isScreenSharing: true })
    );

    expect(c.isScreenSharing).toBe(true);
    expect(mockedBroadcastToRoom).toHaveBeenCalledWith("session-1", "user-1", {
      type: SignalingMessageType.SCREEN_SHARE_STATE,
      userId: "user-1",
      isScreenSharing: true,
    });
  });

  it("updates and broadcasts MIC_STATE", async () => {
    const c = client();

    await handleMessage("session-1", c, JSON.stringify({ type: SignalingMessageType.MIC_STATE, isMicMuted: true }));

    expect(c.isMicMuted).toBe(true);
    expect(mockedBroadcastToRoom).toHaveBeenCalledWith("session-1", "user-1", {
      type: SignalingMessageType.MIC_STATE,
      userId: "user-1",
      isMicMuted: true,
    });
  });

  it("updates and broadcasts CAMERA_STATE", async () => {
    const c = client();

    await handleMessage("session-1", c, JSON.stringify({ type: SignalingMessageType.CAMERA_STATE, isCameraOff: true }));

    expect(c.isCameraOff).toBe(true);
    expect(mockedBroadcastToRoom).toHaveBeenCalledWith("session-1", "user-1", {
      type: SignalingMessageType.CAMERA_STATE,
      userId: "user-1",
      isCameraOff: true,
    });
  });

  it("sends an ERROR for an unrecognized message type", async () => {
    const c = client();

    await handleMessage("session-1", c, JSON.stringify({ type: "not-a-real-type" }));

    expect(c.ws.send).toHaveBeenCalledWith(
      JSON.stringify({ type: SignalingMessageType.ERROR, message: "Unknown message type" })
    );
  });

  it("sends an ERROR for malformed JSON instead of throwing", async () => {
    const c = client();

    await expect(handleMessage("session-1", c, "{not json")).resolves.toBeUndefined();

    expect(c.ws.send).toHaveBeenCalledWith(
      expect.stringContaining(`"type":"${SignalingMessageType.ERROR}"`)
    );
  });
});
