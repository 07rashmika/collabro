import { registerUserSocket, unregisterUserSocket, notifyUser, notifyUsers } from "../user-registry";

function makeWs(readyState: number = 1 /* OPEN */) {
  return { readyState, OPEN: 1, send: jest.fn() };
}

describe("user-registry", () => {
  let counter = 0;
  function userId() {
    return `user-${++counter}`;
  }

  describe("registerUserSocket / notifyUser", () => {
    it("delivers to a registered socket", () => {
      const id = userId();
      const ws = makeWs();
      registerUserSocket(id, ws as unknown as Parameters<typeof registerUserSocket>[1]);

      notifyUser(id, { type: "sessions-changed" });

      expect(ws.send).toHaveBeenCalledWith(JSON.stringify({ type: "sessions-changed" }));
    });

    it("delivers to every socket a user has registered (multiple devices/tabs)", () => {
      const id = userId();
      const ws1 = makeWs();
      const ws2 = makeWs();
      registerUserSocket(id, ws1 as unknown as Parameters<typeof registerUserSocket>[1]);
      registerUserSocket(id, ws2 as unknown as Parameters<typeof registerUserSocket>[1]);

      notifyUser(id, { type: "notifications-changed" });

      expect(ws1.send).toHaveBeenCalledWith(JSON.stringify({ type: "notifications-changed" }));
      expect(ws2.send).toHaveBeenCalledWith(JSON.stringify({ type: "notifications-changed" }));
    });

    it("skips a registered socket that isn't open", () => {
      const id = userId();
      const closed = makeWs(3 /* CLOSED */);
      registerUserSocket(id, closed as unknown as Parameters<typeof registerUserSocket>[1]);

      notifyUser(id, { type: "sessions-changed" });

      expect(closed.send).not.toHaveBeenCalled();
    });

    it("is a no-op for a user with no registered sockets", () => {
      expect(() => notifyUser(userId(), { type: "sessions-changed" })).not.toThrow();
    });
  });

  describe("unregisterUserSocket", () => {
    it("stops delivering to a socket once unregistered", () => {
      const id = userId();
      const ws = makeWs();
      registerUserSocket(id, ws as unknown as Parameters<typeof registerUserSocket>[1]);
      unregisterUserSocket(id, ws as unknown as Parameters<typeof registerUserSocket>[1]);

      notifyUser(id, { type: "sessions-changed" });

      expect(ws.send).not.toHaveBeenCalled();
    });

    it("leaves a user's other sockets registered when only one is removed", () => {
      const id = userId();
      const ws1 = makeWs();
      const ws2 = makeWs();
      registerUserSocket(id, ws1 as unknown as Parameters<typeof registerUserSocket>[1]);
      registerUserSocket(id, ws2 as unknown as Parameters<typeof registerUserSocket>[1]);
      unregisterUserSocket(id, ws1 as unknown as Parameters<typeof registerUserSocket>[1]);

      notifyUser(id, { type: "sessions-changed" });

      expect(ws1.send).not.toHaveBeenCalled();
      expect(ws2.send).toHaveBeenCalled();
    });

    it("is a no-op for a user with no registered sockets", () => {
      expect(() => unregisterUserSocket(userId(), makeWs() as unknown as Parameters<typeof registerUserSocket>[1])).not.toThrow();
    });
  });

  describe("notifyUsers", () => {
    it("notifies every userId in the given iterable", () => {
      const id1 = userId();
      const id2 = userId();
      const ws1 = makeWs();
      const ws2 = makeWs();
      registerUserSocket(id1, ws1 as unknown as Parameters<typeof registerUserSocket>[1]);
      registerUserSocket(id2, ws2 as unknown as Parameters<typeof registerUserSocket>[1]);

      notifyUsers([id1, id2], { type: "sessions-changed" });

      expect(ws1.send).toHaveBeenCalled();
      expect(ws2.send).toHaveBeenCalled();
    });
  });
});
