import { PrismaService } from "../../infrastructure/database/prisma.service";
import { getFirebaseApp } from "../../infrastructure/push/firebase-admin";

export type PushCategory = "messages" | "connections" | "videoSessions";

export async function sendPushToUser(
  prisma: PrismaService,
  userId: string,
  category: PushCategory,
  payload: { title: string; body: string; data?: Record<string, string> },
) {
  const app = getFirebaseApp();
  if (!app) return;

  const user = await prisma.client.user.findUnique({
    where: { id: userId },
    select: {
      notifyMessages: true,
      notifyConnections: true,
      notifyVideoSessions: true,
    },
  });
  if (!user) return;

  const enabled =
    category === "messages"
      ? user.notifyMessages
      : category === "connections"
        ? user.notifyConnections
        : user.notifyVideoSessions;
  if (!enabled) return;

  const tokens = await prisma.client.deviceToken.findMany({
    where: { userId },
    select: { id: true, token: true },
  });
  if (tokens.length === 0) return;

  const response = await app.messaging().sendEachForMulticast({
    tokens: tokens.map((t) => t.token),
    notification: { title: payload.title, body: payload.body },
    data: payload.data ?? {},
    android: {
      priority: "high",
      notification: { channelId: "high_importance_channel" },
    },
  });

  const staleIds: string[] = [];
  response.responses.forEach((r, i) => {
    if (
      !r.success &&
      (r.error?.code === "messaging/registration-token-not-registered" ||
        r.error?.code === "messaging/invalid-registration-token")
    ) {
      staleIds.push(tokens[i].id);
    }
  });
  if (staleIds.length > 0) {
    await prisma.client.deviceToken.deleteMany({
      where: { id: { in: staleIds } },
    });
  }
}
