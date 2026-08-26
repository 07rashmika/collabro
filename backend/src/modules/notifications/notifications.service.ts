import { PrismaService } from "../../infrastructure/database/prisma.service";

const notificationSelect = {
  id: true,
  type: true,
  isRead: true,
  createdAt: true,
  connectionId: true,
  actor: { select: { id: true, name: true, avatarUrl: true } },
  connection: { select: { status: true } },
  sessionId: true,
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
