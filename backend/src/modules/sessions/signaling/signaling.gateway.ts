import { Server as HttpServer, IncomingMessage } from "http";
import { Socket } from "net";
import { WebSocket, WebSocketServer } from "ws";
import { TokenUtil } from "../../../common/utils/token.util";
import { STUDENT_EMAIL_DOMAINS } from "../../../common/config/student-domains";
import { PrismaService } from "../../../infrastructure/database/prisma.service";
import { SessionsService } from "../sessions.service";
import { SummarizerClient } from "../../summaries/summarizer.client";
import { SummariesService } from "../../summaries/summaries.service";
import { TranscriptionClient } from "../transcription.client";
import { SignalingMessageType, InboundSignalingMessage } from "./signaling.types";
import {
  ConnectedClient,
  joinRoom,
  leaveRoom,
  broadcastToRoom,
  sendToUser,
  getClient,
} from "./room-registry";
import { registerUserSocket, unregisterUserSocket } from "./user-registry";

const SIGNALING_PATH = "/sessions/ws";
const NOTIFICATIONS_PATH = "/users/ws";

const tokenUtil = new TokenUtil();
const prisma = PrismaService.getInstance();
const summarizerClient = new SummarizerClient(process.env.SUMMARIZER_URL || "http://localhost:8000");
const transcriptionClient = new TranscriptionClient(process.env.SUMMARIZER_URL || "http://localhost:8000");
const summariesService = new SummariesService(summarizerClient);
const sessionsService = new SessionsService(prisma, summariesService, transcriptionClient);

function rejectUpgrade(socket: Socket, statusLine: string) {
  socket.write(`HTTP/1.1 ${statusLine}\r\n\r\n`);
  socket.destroy();
}

// Both the per-session signaling socket and the per-user notifications
// socket share the HTTP server's single "upgrade" event, so both live here
// and are routed by pathname — two independent listeners would otherwise
// race to call handleUpgrade on the same incoming request.
export function attachSignalingServer(httpServer: HttpServer): void {
  const sessionsWss = new WebSocketServer({ noServer: true });
  const notificationsWss = new WebSocketServer({ noServer: true });

  httpServer.on("upgrade", (req: IncomingMessage, socket: Socket, head: Buffer) => {
    const url = new URL(req.url ?? "", "http://localhost");
    if (url.pathname === SIGNALING_PATH) {
      void handleSignalingUpgrade(sessionsWss, req, socket, head);
    } else if (url.pathname === NOTIFICATIONS_PATH) {
      void handleNotificationsUpgrade(notificationsWss, req, socket, head);
    } else {
      rejectUpgrade(socket, "404 Not Found");
    }
  });

  sessionsWss.on("connection", (ws: WebSocket, sessionId: string, client: ConnectedClient) => {
    handleConnection(ws, sessionId, client);
  });

  notificationsWss.on("connection", (ws: WebSocket, userId: string) => {
    registerUserSocket(userId, ws);
    ws.on("close", () => unregisterUserSocket(userId, ws));
  });
}

/// Shared by both upgrade paths — verifies the access token and that the
/// caller is a student, rejecting the upgrade otherwise. Returns null (after
/// already rejecting) on any failure.
async function authenticateUpgrade(
  req: IncomingMessage,
  socket: Socket,
  token: string | null
): Promise<{ sub: string; email: string } | null> {
  if (!token) {
    rejectUpgrade(socket, "400 Bad Request");
    return null;
  }
  const payload = tokenUtil.verifyAccessToken(token);
  if (!payload) {
    rejectUpgrade(socket, "401 Unauthorized");
    return null;
  }
  const isStudent = STUDENT_EMAIL_DOMAINS.some((d) => payload.email.endsWith(`@${d}`));
  if (!isStudent) {
    rejectUpgrade(socket, "403 Forbidden");
    return null;
  }
  return payload;
}

async function handleSignalingUpgrade(
  wss: WebSocketServer,
  req: IncomingMessage,
  socket: Socket,
  head: Buffer
): Promise<void> {
  const url = new URL(req.url ?? "", "http://localhost");
  const sessionId = url.searchParams.get("sessionId");
  if (!sessionId) {
    rejectUpgrade(socket, "400 Bad Request");
    return;
  }

  const payload = await authenticateUpgrade(req, socket, url.searchParams.get("token"));
  if (!payload) return;

  const membership = await prisma.client.sessionParticipant.findUnique({
    where: { sessionId_userId: { sessionId, userId: payload.sub } },
    include: { session: { select: { status: true } } },
  });
  if (!membership || membership.session.status === "CLOSED") {
    rejectUpgrade(socket, "403 Forbidden");
    return;
  }

  const user = await prisma.client.user.findUnique({
    where: { id: payload.sub },
    select: { name: true },
  });

  const client: ConnectedClient = {
    ws: null as unknown as WebSocket, // set once handleUpgrade completes below
    userId: payload.sub,
    name: user?.name ?? payload.email,
    isMicMuted: false,
    isCameraOff: false,
    isScreenSharing: false,
  };

  wss.handleUpgrade(req, socket, head, (ws) => {
    client.ws = ws;
    wss.emit("connection", ws, sessionId, client);
  });
}

/// The notifications channel needs no session/room membership check — it's
/// a personal push channel any authenticated student can open.
async function handleNotificationsUpgrade(
  wss: WebSocketServer,
  req: IncomingMessage,
  socket: Socket,
  head: Buffer
): Promise<void> {
  const url = new URL(req.url ?? "", "http://localhost");
  const payload = await authenticateUpgrade(req, socket, url.searchParams.get("token"));
  if (!payload) return;

  wss.handleUpgrade(req, socket, head, (ws) => {
    wss.emit("connection", ws, payload.sub);
  });
}

function handleConnection(
  ws: WebSocket,
  sessionId: string,
  client: ConnectedClient
): void {
  const wasAlreadyConnected = !!getClient(sessionId, client.userId);
  const existingParticipants = joinRoom(sessionId, client);

  send(ws, {
    type: wasAlreadyConnected
      ? SignalingMessageType.RECONNECTED_STATE
      : SignalingMessageType.ROOM_SNAPSHOT,
    participants: existingParticipants,
  });

  broadcastToRoom(sessionId, client.userId, {
    type: SignalingMessageType.PARTICIPANT_JOINED,
    participant: {
      userId: client.userId,
      name: client.name,
      isMicMuted: client.isMicMuted,
      isCameraOff: client.isCameraOff,
      isScreenSharing: client.isScreenSharing,
    },
  });

  ws.on("message", (raw) => {
    void handleMessage(sessionId, client, raw.toString());
  });

  ws.on("close", () => {
    leaveRoom(sessionId, client.userId);
    broadcastToRoom(sessionId, client.userId, {
      type: SignalingMessageType.PARTICIPANT_LEFT,
      userId: client.userId,
    });
  });
}

async function handleMessage(sessionId: string, client: ConnectedClient, raw: string): Promise<void> {
  try {
    const message = JSON.parse(raw) as InboundSignalingMessage;

    switch (message.type) {
      case SignalingMessageType.OFFER:
      case SignalingMessageType.ANSWER:
      case SignalingMessageType.ICE_CANDIDATE: {
        const delivered = sendToUser(sessionId, message.targetUserId, {
          ...message,
          fromUserId: client.userId,
        });
        if (!delivered) {
          send(client.ws, { type: SignalingMessageType.ERROR, message: "Target participant not connected" });
        }
        break;
      }

      case SignalingMessageType.CHAT_MESSAGE: {
        const saved = await sessionsService.sendMessage(sessionId, client.userId, {
          content: message.content,
        });
        broadcastToRoom(
          sessionId,
          client.userId,
          {
            type: SignalingMessageType.CHAT_MESSAGE,
            message: {
              id: saved.id,
              sessionId,
              senderId: saved.sender.id,
              senderName: saved.sender.name,
              content: saved.content,
              createdAt: saved.createdAt,
            },
          },
          { includeSender: true }
        );
        break;
      }

      case SignalingMessageType.SCREEN_SHARE_STATE:
        client.isScreenSharing = message.isScreenSharing;
        broadcastToRoom(sessionId, client.userId, {
          type: SignalingMessageType.SCREEN_SHARE_STATE,
          userId: client.userId,
          isScreenSharing: message.isScreenSharing,
        });
        break;

      case SignalingMessageType.MIC_STATE:
        client.isMicMuted = message.isMicMuted;
        broadcastToRoom(sessionId, client.userId, {
          type: SignalingMessageType.MIC_STATE,
          userId: client.userId,
          isMicMuted: message.isMicMuted,
        });
        break;

      case SignalingMessageType.CAMERA_STATE:
        client.isCameraOff = message.isCameraOff;
        broadcastToRoom(sessionId, client.userId, {
          type: SignalingMessageType.CAMERA_STATE,
          userId: client.userId,
          isCameraOff: message.isCameraOff,
        });
        break;

      default:
        send(client.ws, { type: SignalingMessageType.ERROR, message: "Unknown message type" });
    }
  } catch (err) {
    send(client.ws, {
      type: SignalingMessageType.ERROR,
      message: `Invalid message: ${(err as Error).message}`,
    });
  }
}

function send(ws: WebSocket, message: unknown): void {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(message));
  }
}
