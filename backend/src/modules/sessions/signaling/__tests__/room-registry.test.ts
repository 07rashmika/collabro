import {
  joinRoom,
  leaveRoom,
  getClient,
  getRoomParticipants,
  broadcastToRoom,
  sendToUser,
  endRoom,
  ConnectedClient,
} from "../room-registry";

function makeWs(readyState: number = 1 /* OPEN */) {
  return {
    readyState,
    OPEN: 1,
    send: jest.fn(),
    close: jest.fn(),
  };
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

describe("room-registry", () => {
  // Rooms are process-global Maps keyed by sessionId — use a fresh sessionId
  // per test (via a counter) so tests can't see each other's state.
  let counter = 0;
  function sessionId() {
    return `room-${++counter}`;
  }

  describe("joinRoom", () => {
    it("returns no existing participants for the first joiner", () => {
      const id = sessionId();
      const existing = joinRoom(id, makeClient());
      expect(existing).toEqual([]);
    });

    it("returns the other already-connected participants for a later joiner", () => {
      const id = sessionId();
      joinRoom(id, makeClient({ userId: "user-1", name: "Alice" }));
      const existing = joinRoom(id, makeClient({ userId: "user-2", name: "Bob" }));

      expect(existing).toEqual([
        { userId: "user-1", name: "Alice", isMicMuted: false, isCameraOff: false, isScreenSharing: false },
      ]);
    });

    it("re-joining the same userId replaces its client entry rather than duplicating it", () => {
      const id = sessionId();
      joinRoom(id, makeClient({ userId: "user-1", name: "Alice" }));
      joinRoom(id, makeClient({ userId: "user-1", name: "Alice (reconnected)" }));

      expect(getRoomParticipants(id)).toHaveLength(1);
      expect(getRoomParticipants(id)[0]?.name).toBe("Alice (reconnected)");
    });
  });

  describe("leaveRoom", () => {
    it("removes the client and deletes the room once empty", () => {
      const id = sessionId();
      joinRoom(id, makeClient({ userId: "user-1" }));

      leaveRoom(id, "user-1");

      expect(getClient(id, "user-1")).toBeUndefined();
      expect(getRoomParticipants(id)).toEqual([]);
    });

    it("leaves other participants intact when one leaves", () => {
      const id = sessionId();
      joinRoom(id, makeClient({ userId: "user-1" }));
      joinRoom(id, makeClient({ userId: "user-2" }));

      leaveRoom(id, "user-1");

      expect(getClient(id, "user-1")).toBeUndefined();
      expect(getClient(id, "user-2")).toBeDefined();
    });

    it("is a no-op for a room that doesn't exist", () => {
      expect(() => leaveRoom(sessionId(), "nobody")).not.toThrow();
    });
  });

  describe("broadcastToRoom", () => {
    it("sends to every other connected client but not the sender, by default", () => {
      const id = sessionId();
      const sender = makeClient({ userId: "sender" });
      const peer1 = makeClient({ userId: "peer-1" });
      const peer2 = makeClient({ userId: "peer-2" });
      joinRoom(id, sender);
      joinRoom(id, peer1);
      joinRoom(id, peer2);

      broadcastToRoom(id, "sender", { type: "hello" });

      expect(sender.ws.send).not.toHaveBeenCalled();
      expect(peer1.ws.send).toHaveBeenCalledWith(JSON.stringify({ type: "hello" }));
      expect(peer2.ws.send).toHaveBeenCalledWith(JSON.stringify({ type: "hello" }));
    });

    it("includes the sender when includeSender is true", () => {
      const id = sessionId();
      const sender = makeClient({ userId: "sender" });
      joinRoom(id, sender);

      broadcastToRoom(id, "sender", { type: "chat" }, { includeSender: true });

      expect(sender.ws.send).toHaveBeenCalledWith(JSON.stringify({ type: "chat" }));
    });

    it("skips clients whose socket isn't open", () => {
      const id = sessionId();
      const sender = makeClient({ userId: "sender" });
      const closedPeer = makeClient({ userId: "closed-peer", ws: makeWs(3 /* CLOSED */) as unknown as ConnectedClient["ws"] });
      joinRoom(id, sender);
      joinRoom(id, closedPeer);

      broadcastToRoom(id, "sender", { type: "hello" });

      expect(closedPeer.ws.send).not.toHaveBeenCalled();
    });

    it("is a no-op for a room that doesn't exist", () => {
      expect(() => broadcastToRoom(sessionId(), "sender", { type: "hello" })).not.toThrow();
    });
  });

  describe("sendToUser", () => {
    it("sends to the target and returns true when connected", () => {
      const id = sessionId();
      const target = makeClient({ userId: "target" });
      joinRoom(id, target);

      const delivered = sendToUser(id, "target", { type: "offer" });

      expect(delivered).toBe(true);
      expect(target.ws.send).toHaveBeenCalledWith(JSON.stringify({ type: "offer" }));
    });

    it("returns false when the target isn't in the room", () => {
      const id = sessionId();
      joinRoom(id, makeClient({ userId: "someone-else" }));

      expect(sendToUser(id, "target", { type: "offer" })).toBe(false);
    });

    it("returns false when the target's socket isn't open", () => {
      const id = sessionId();
      const target = makeClient({ userId: "target", ws: makeWs(3 /* CLOSED */) as unknown as ConnectedClient["ws"] });
      joinRoom(id, target);

      expect(sendToUser(id, "target", { type: "offer" })).toBe(false);
    });
  });

  describe("getClient", () => {
    it("returns undefined for a room/user that doesn't exist", () => {
      expect(getClient(sessionId(), "nobody")).toBeUndefined();
    });
  });

  describe("endRoom", () => {
    it("messages and closes every connected client's socket, then deletes the room", () => {
      const id = sessionId();
      const a = makeClient({ userId: "a" });
      const b = makeClient({ userId: "b" });
      joinRoom(id, a);
      joinRoom(id, b);

      endRoom(id, { type: "session-ended" });

      expect(a.ws.send).toHaveBeenCalledWith(JSON.stringify({ type: "session-ended" }));
      expect(b.ws.send).toHaveBeenCalledWith(JSON.stringify({ type: "session-ended" }));
      expect(a.ws.close).toHaveBeenCalled();
      expect(b.ws.close).toHaveBeenCalled();
      expect(getRoomParticipants(id)).toEqual([]);
    });

    it("doesn't message a client whose socket isn't open, but still closes it", () => {
      const id = sessionId();
      const closed = makeClient({ userId: "closed", ws: makeWs(3 /* CLOSED */) as unknown as ConnectedClient["ws"] });
      joinRoom(id, closed);

      endRoom(id, { type: "session-ended" });

      expect(closed.ws.send).not.toHaveBeenCalled();
      expect(closed.ws.close).toHaveBeenCalled();
    });

    it("is a no-op for a room that doesn't exist", () => {
      expect(() => endRoom(sessionId(), { type: "session-ended" })).not.toThrow();
    });
  });
});
