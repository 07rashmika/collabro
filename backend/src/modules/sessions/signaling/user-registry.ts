import { WebSocket } from "ws";

// Per-user (not per-session) socket registry for the "/users/ws" channel —
// pushes lightweight "something about your sessions changed, go refetch"
// notifications to every device/tab a user currently has open, independent
// of whether they're connected to any particular session's room.
const connections = new Map<string, Set<WebSocket>>();

export function registerUserSocket(userId: string, ws: WebSocket): void {
  let sockets = connections.get(userId);
  if (!sockets) {
    sockets = new Set();
    connections.set(userId, sockets);
  }
  sockets.add(ws);
}

export function unregisterUserSocket(userId: string, ws: WebSocket): void {
  const sockets = connections.get(userId);
  if (!sockets) return;
  sockets.delete(ws);
  if (sockets.size === 0) connections.delete(userId);
}

export function notifyUser(userId: string, message: unknown): void {
  const sockets = connections.get(userId);
  if (!sockets) return;
  const payload = JSON.stringify(message);
  for (const ws of sockets) {
    if (ws.readyState === ws.OPEN) ws.send(payload);
  }
}

export function notifyUsers(userIds: Iterable<string>, message: unknown): void {
  for (const userId of userIds) notifyUser(userId, message);
}
