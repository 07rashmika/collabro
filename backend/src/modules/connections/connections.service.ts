import { PrismaService } from "../../infrastructure/database/prisma.service";
import { AppError } from "../../common/errors/app-error";
import { notifyUsers } from "../sessions/signaling/user-registry";
import { NotificationMessageType } from "../sessions/signaling/signaling.types";
import { SendConnectionRequestDto } from "./connections.schema";
import { ConnectionStatusView } from "./connections.types";
import { sendPushToUser } from "../notifications/push.service";

export async function getConnectionStatuses(
  prisma: PrismaService,
  userId: string,
  otherUserIds: string[],
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
  }

  return statuses;
}

export async function getConnectedUserIds(
  prisma: PrismaService,
  userId: string,
): Promise<string[]> {
  const connections = await prisma.client.connection.findMany({
    where: {
      status: "ACCEPTED",
      OR: [{ requesterId: userId }, { addresseeId: userId }],
    },
    select: { requesterId: true, addresseeId: true },
  });
  return connections.map((c) =>
    c.requesterId === userId ? c.addresseeId : c.requesterId,
  );
}

export async function getConnectedUsers(prisma: PrismaService, userId: string) {
  const connections = await prisma.client.connection.findMany({
    where: {
      status: "ACCEPTED",
      OR: [{ requesterId: userId }, { addresseeId: userId }],
    },
    select: {
      requesterId: true,
      addresseeId: true,
      requester: {
        select: { id: true, name: true, email: true, avatarUrl: true },
      },
      addressee: {
        select: { id: true, name: true, email: true, avatarUrl: true },
      },
    },
  });
  return connections.map((c) =>
    c.requesterId === userId ? c.addressee : c.requester,
  );
}

export class ConnectionsService {
  constructor(private readonly prisma: PrismaService) {}

  async getMyConnectedUserIds(userId: string) {
    return getConnectedUserIds(this.prisma, userId);
  }

  async getMyConnectedUsers(userId: string) {
    return getConnectedUsers(this.prisma, userId);
  }

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

    await this.prisma.client.connection.delete({
      where: { id: connection.id },
    });
    notifyUsers([userId, otherUserId], {
      type: NotificationMessageType.NOTIFICATIONS_CHANGED,
    });
  }

  async sendRequest(requesterId: string, dto: SendConnectionRequestDto) {
    const { addresseeId } = dto;
    if (addresseeId === requesterId) {
      throw new AppError("You can't connect with yourself", 400);
    }

    const addressee = await this.prisma.client.user.findUnique({
      where: { id: addresseeId },
    });
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
      return this.accept(existing.id, requesterId);
    }

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
    await this.prisma.client.connection.delete({
      where: { id: connection.id },
    });

    notifyUsers([addresseeId], {
      type: NotificationMessageType.NOTIFICATIONS_CHANGED,
    });
  }

  async accept(connectionId: string, userId: string) {
    const connection = await this.prisma.client.connection.findUnique({
      where: { id: connectionId },
    });
    if (!connection) throw new AppError("Connection request not found", 404);
    if (connection.addresseeId !== userId)
      throw new AppError("Not your request to accept", 403);
    if (connection.status !== "PENDING")
      throw new AppError("Request is no longer pending", 409);

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

    notifyUsers([connection.requesterId, userId], {
      type: NotificationMessageType.NOTIFICATIONS_CHANGED,
    });

    const accepter = await this.prisma.client.user.findUnique({
      where: { id: userId },
      select: { name: true },
    });
    await sendPushToUser(this.prisma, connection.requesterId, "connections", {
      title: "Connection accepted",
      body: `${accepter?.name ?? "Someone"} accepted your connection request`,
      data: { type: "CONNECTION_ACCEPTED", connectionId },
    });

    return updated;
  }

  async decline(connectionId: string, userId: string) {
    const connection = await this.prisma.client.connection.findUnique({
      where: { id: connectionId },
    });
    if (!connection) throw new AppError("Connection request not found", 404);
    if (connection.addresseeId !== userId)
      throw new AppError("Not your request to decline", 403);
    if (connection.status !== "PENDING")
      throw new AppError("Request is no longer pending", 409);

    const updated = await this.prisma.client.connection.update({
      where: { id: connectionId },
      data: { status: "DECLINED" },
    });

    await this.markTriggeringNotificationRead(connectionId, userId);
    notifyUsers([connection.requesterId, userId], {
      type: NotificationMessageType.NOTIFICATIONS_CHANGED,
    });
    return updated;
  }

  private async notifyRequest(
    connectionId: string,
    addresseeId: string,
    requesterId: string,
  ) {
    await this.prisma.client.notification.create({
      data: {
        recipientId: addresseeId,
        actorId: requesterId,
        type: "CONNECTION_REQUEST",
        connectionId,
      },
    });
    notifyUsers([addresseeId], {
      type: NotificationMessageType.NOTIFICATIONS_CHANGED,
    });

    const requester = await this.prisma.client.user.findUnique({
      where: { id: requesterId },
      select: { name: true },
    });
    await sendPushToUser(this.prisma, addresseeId, "connections", {
      title: "New connection request",
      body: `${requester?.name ?? "Someone"} wants to connect with you`,
      data: { type: "CONNECTION_REQUEST", connectionId },
    });
  }

  private async markTriggeringNotificationRead(
    connectionId: string,
    recipientId: string,
  ) {
    await this.prisma.client.notification.updateMany({
      where: { connectionId, recipientId, type: "CONNECTION_REQUEST" },
      data: { isRead: true },
    });
  }
}
