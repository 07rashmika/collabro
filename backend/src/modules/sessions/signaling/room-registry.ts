import { WebSocket } from "ws";
import { CallParticipant } from "./signaling.types";

export interface ConnectedClient {
  ws: WebSocket;
  userId: string;
  name: string;
  isMicMuted: boolean;
  isCameraOff: boolean;
  isScreenSharing: boolean;
}

interface Room {
  sessionId: string;
  clients: Map<string, ConnectedClient>; // keyed by userId
}

const rooms = new Map<string, Room>();

function toParticipant(client: ConnectedClient): CallParticipant {
  return {
    userId: client.userId,
    name: client.name,
    isMicMuted: client.isMicMuted,
    isCameraOff: client.isCameraOff,
    isScreenSharing: client.isScreenSharing,
  };
}

/** Adds a client to its session room (creating the room if needed) and
 * returns the other participants already present, for the join snapshot. */
export function joinRoom(sessionId: string, client: ConnectedClient): CallParticipant[] {
  let room = rooms.get(sessionId);
  if (!room) {
    room = { sessionId, clients: new Map() };
    rooms.set(sessionId, room);
  }

  const existing = Array.from(room.clients.values()).map(toParticipant);
  room.clients.set(client.userId, client);
  return existing;
}

/** Removes a client from its room, deleting the room entirely once empty. */
export function leaveRoom(sessionId: string, userId: string): void {
  const room = rooms.get(sessionId);
  if (!room) return;

  room.clients.delete(userId);
  if (room.clients.size === 0) {
    rooms.delete(sessionId);
  }
}

export function getClient(sessionId: string, userId: string): ConnectedClient | undefined {
  return rooms.get(sessionId)?.clients.get(userId);
}

export function getRoomParticipants(sessionId: string): CallParticipant[] {
  const room = rooms.get(sessionId);
  if (!room) return [];
  return Array.from(room.clients.values()).map(toParticipant);
}

/** Sends a JSON message to every client in the room except (by default) the sender. */
export function broadcastToRoom(
  sessionId: string,
  senderUserId: string,
  message: unknown,
  { includeSender = false }: { includeSender?: boolean } = {}
): void {
  const room = rooms.get(sessionId);
  if (!room) return;

  const payload = JSON.stringify(message);
  for (const client of room.clients.values()) {
    if (!includeSender && client.userId === senderUserId) continue;
    if (client.ws.readyState === client.ws.OPEN) {
      client.ws.send(payload);
    }
  }
}

/** Sends a JSON message to exactly one participant in the room, if connected. */
export function sendToUser(sessionId: string, targetUserId: string, message: unknown): boolean {
  const client = getClient(sessionId, targetUserId);
  if (!client || client.ws.readyState !== client.ws.OPEN) return false;
  client.ws.send(JSON.stringify(message));
  return true;
}

/** Notifies everyone still connected that the session has permanently ended,
 * then forcibly closes their sockets and drops the room — used when a
 * session is closed (by its creator, or auto-closed) so no one is left
 * talking into a call/chat that no longer exists. */
export function endRoom(sessionId: string, message: unknown): void {
  const room = rooms.get(sessionId);
  if (!room) return;

  const payload = JSON.stringify(message);
  for (const client of room.clients.values()) {
    if (client.ws.readyState === client.ws.OPEN) {
      client.ws.send(payload);
    }
    client.ws.close();
  }
  rooms.delete(sessionId);
}
