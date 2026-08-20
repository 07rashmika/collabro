import { PrismaService } from "../../infrastructure/database/prisma.service";

const notificationSelect = {
  id: true,
  type: true,
  isRead: true,
  createdAt: true,
  connectionId: true,
  actor: { select: { id: true, name: true, avatarUrl: true } },
  // Lets the client tell a still-pending CONNECTION_REQUEST apart from one
  // that's since been accepted/declined, so a responded-to notification
  // renders its outcome instead of stale Accept/Decline buttons.
  connection: { select: { status: true } },
  sessionId: true,
  // Just enough to render "X invited you to '<title>'" — the full session
  // is fetched separately (with a fresh participant/expiry check) if the
  // client navigates into it.
  session: { select: { title: true } },
} as const;

export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async getMyNotifications(userId: string) {
    const [notifications, unreadCount] = await Promise.all([
      this.prisma.client.notification.findMany({
        where: { recipientId: userId },
        select: notificationSelect,
        orderBy: { createdAt: "desc" },
      }),
      this.prisma.client.notification.count({
        where: { recipientId: userId, isRead: false },
      }),
    ]);

    return { notifications, unreadCount };
  }

  async markAllRead(userId: string) {
    await this.prisma.client.notification.updateMany({
      where: { recipientId: userId, isRead: false },
      data: { isRead: true },
    });
  }
}
