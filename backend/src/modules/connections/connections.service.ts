import { PrismaService } from "../../infrastructure/database/prisma.service";
import { AppError } from "../../common/errors/app-error";
import { notifyUsers } from "../sessions/signaling/user-registry";
import { NotificationMessageType } from "../sessions/signaling/signaling.types";
import { SendConnectionRequestDto } from "./connections.schema";
import { ConnectionStatusView } from "./connections.types";

/// Batch status lookup for a list of other users, from the caller's point of
/// view — used by users.service.ts and matching.service.ts to annotate
/// listings so a Connect button knows what state to render without a
/// separate round trip per card.
export async function getConnectionStatuses(
  prisma: PrismaService,
  userId: string,
  otherUserIds: string[]
): Promise<Map<string, ConnectionStatusView>> {
  const statuses = new Map<string, ConnectionStatusView>();
  if (otherUserIds.length === 0) return statuses;

  const connections = await prisma.client.connection.findMany({
    where: {
      OR: [
        { requesterId: userId, addresseeId: { in: otherUserIds } },
        { addresseeId: userId, requesterId: { in: otherUserIds } },
      ],
    },
  });

  for (const c of connections) {
    const otherId = c.requesterId === userId ? c.addresseeId : c.requesterId;
    if (c.status === "ACCEPTED") {
      statuses.set(otherId, "CONNECTED");
    } else if (c.status === "PENDING" && c.requesterId === userId) {
      statuses.set(otherId, "REQUESTED");
    }
    // A PENDING request the other side sent me, or a DECLINED one, is left
    // unset here and defaults to "NONE" downstream — from my side, nothing
    // stops me from (re-)sending a request.
  }

  return statuses;
}

/// The other-side user IDs of every ACCEPTED connection a user has — used
/// by sessions.service.ts to surface a connection's public sessions in
/// Discover regardless of skill overlap (connecting is a stronger
/// relevance signal than shared skills).
export async function getConnectedUserIds(prisma: PrismaService, userId: string): Promise<string[]> {
  const connections = await prisma.client.connection.findMany({
    where: {
      status: "ACCEPTED",
      OR: [{ requesterId: userId }, { addresseeId: userId }],
    },
    select: { requesterId: true, addresseeId: true },
  });
  return connections.map((c) => (c.requesterId === userId ? c.addresseeId : c.requesterId));
}

/// Full profile (not just the id) of the other side of every ACCEPTED
/// connection a user has — used to populate "invite someone I'm already
/// connected with" pickers, as opposed to match suggestions.
export async function getConnectedUsers(prisma: PrismaService, userId: string) {
  const connections = await prisma.client.connection.findMany({
    where: {
      status: "ACCEPTED",
      OR: [{ requesterId: userId }, { addresseeId: userId }],
    },
    select: {
      requesterId: true,
      addresseeId: true,
      requester: { select: { id: true, name: true, email: true, avatarUrl: true } },
      addressee: { select: { id: true, name: true, email: true, avatarUrl: true } },
    },
  });
  return connections.map((c) => (c.requesterId === userId ? c.addressee : c.requester));
}

export class ConnectionsService {
  constructor(private readonly prisma: PrismaService) {}

  async getMyConnectedUserIds(userId: string) {
    return getConnectedUserIds(this.prisma, userId);
  }

  async getMyConnectedUsers(userId: string) {
    return getConnectedUsers(this.prisma, userId);
  }

  /// Either side of an ACCEPTED connection can end it — unlike declining a
  /// still-PENDING request, there's no "whose call is it" asymmetry once
  /// both sides have already agreed to connect.
  async removeConnection(userId: string, otherUserId: string) {
    const connection = await this.prisma.client.connection.findFirst({
      where: {
        status: "ACCEPTED",
        OR: [
          { requesterId: userId, addresseeId: otherUserId },
          { requesterId: otherUserId, addresseeId: userId },
        ],
      },
    });
    if (!connection) throw new AppError("Connection not found", 404);

    await this.prisma.client.connection.delete({ where: { id: connection.id } });
    // Both sides need to know — the other party's connections list and
    // connect-button state should update live too, not just the remover's.
    notifyUsers([userId, otherUserId], { type: NotificationMessageType.NOTIFICATIONS_CHANGED });
  }

  async sendRequest(requesterId: string, dto: SendConnectionRequestDto) {
    const { addresseeId } = dto;
    if (addresseeId === requesterId) {
      throw new AppError("You can't connect with yourself", 400);
    }

    const addressee = await this.prisma.client.user.findUnique({ where: { id: addresseeId } });
    if (!addressee) {
      throw new AppError("User not found", 404);
    }

    const existing = await this.prisma.client.connection.findFirst({
      where: {
        OR: [
          { requesterId, addresseeId },
          { requesterId: addresseeId, addresseeId: requesterId },
        ],
      },
    });

    if (!existing) {
      const connection = await this.prisma.client.connection.create({
        data: { requesterId, addresseeId, status: "PENDING" },
      });
      await this.notifyRequest(connection.id, addresseeId, requesterId);
      return connection;
    }

    if (existing.status === "ACCEPTED") {
      throw new AppError("Already connected", 409);
    }

    if (existing.status === "PENDING") {
      if (existing.requesterId === requesterId) {
        throw new AppError("Request already sent", 409);
      }
      // The other side already requested me — mutual interest, accept it
      // outright instead of leaving two independent pending requests.
      return this.accept(existing.id, requesterId);
    }

    // DECLINED — let them try again, flipped to the new direction.
    const connection = await this.prisma.client.connection.update({
      where: { id: existing.id },
      data: { requesterId, addresseeId, status: "PENDING" },
    });
    await this.notifyRequest(connection.id, addresseeId, requesterId);
    return connection;
  }

  async cancelRequest(requesterId: string, addresseeId: string) {
    const connection = await this.prisma.client.connection.findFirst({
      where: { requesterId, addresseeId, status: "PENDING" },
    });
    if (!connection) throw new AppError("Request not found", 404);

    await this.prisma.client.notification.deleteMany({
      where: { connectionId: connection.id, type: "CONNECTION_REQUEST" },
    });
    await this.prisma.client.connection.delete({ where: { id: connection.id } });

    notifyUsers([addresseeId], { type: NotificationMessageType.NOTIFICATIONS_CHANGED });
  }

  async accept(connectionId: string, userId: string) {
    const connection = await this.prisma.client.connection.findUnique({ where: { id: connectionId } });
    if (!connection) throw new AppError("Connection request not found", 404);
    if (connection.addresseeId !== userId) throw new AppError("Not your request to accept", 403);
    if (connection.status !== "PENDING") throw new AppError("Request is no longer pending", 409);

    const updated = await this.prisma.client.connection.update({
      where: { id: connectionId },
      data: { status: "ACCEPTED" },
    });

    await this.markTriggeringNotificationRead(connectionId, userId);
    await this.prisma.client.notification.create({
      data: {
        recipientId: connection.requesterId,
        actorId: userId,
        type: "CONNECTION_ACCEPTED",
        connectionId,
      },
    });

    notifyUsers([connection.requesterId, userId], { type: NotificationMessageType.NOTIFICATIONS_CHANGED });
    return updated;
  }

  async decline(connectionId: string, userId: string) {
    const connection = await this.prisma.client.connection.findUnique({ where: { id: connectionId } });
    if (!connection) throw new AppError("Connection request not found", 404);
    if (connection.addresseeId !== userId) throw new AppError("Not your request to decline", 403);
    if (connection.status !== "PENDING") throw new AppError("Request is no longer pending", 409);

    const updated = await this.prisma.client.connection.update({
      where: { id: connectionId },
      data: { status: "DECLINED" },
    });

    await this.markTriggeringNotificationRead(connectionId, userId);
    // Notify the requester too, not just the decliner — otherwise their
    // client never learns the request was declined and keeps showing
    // "Requested" instead of resetting to "Connect".
    notifyUsers([connection.requesterId, userId], { type: NotificationMessageType.NOTIFICATIONS_CHANGED });
    return updated;
  }

  private async notifyRequest(connectionId: string, addresseeId: string, requesterId: string) {
    await this.prisma.client.notification.create({
      data: { recipientId: addresseeId, actorId: requesterId, type: "CONNECTION_REQUEST", connectionId },
    });
    notifyUsers([addresseeId], { type: NotificationMessageType.NOTIFICATIONS_CHANGED });
  }

  private async markTriggeringNotificationRead(connectionId: string, recipientId: string) {
    await this.prisma.client.notification.updateMany({
      where: { connectionId, recipientId, type: "CONNECTION_REQUEST" },
      data: { isRead: true },
    });
  }
}
