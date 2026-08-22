import { PrismaService } from "../../infrastructure/database/prisma.service";
import { getFirebaseApp } from "../../infrastructure/push/firebase-admin";

export type PushCategory = "messages" | "connections" | "videoSessions";

/// Sends a push notification to every device registered for `userId`, but
/// only if both (a) Firebase is configured and (b) the user hasn't turned
/// that category off (server-side mirror of the drawer toggle — see
/// User.notifyMessages/notifyConnections/notifyVideoSessions). Silently a
/// no-op otherwise; a failed/skipped push should never break the action
/// that triggered it (accepting a request, creating a session, etc).
export async function sendPushToUser(
  prisma: PrismaService,
  userId: string,
  category: PushCategory,
  payload: { title: string; body: string; data?: Record<string, string> }
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
    // `channelId` must match the high-importance channel created client-side
    // (push_notifications_service.dart) — without it Android shows this on
    // its own default channel, which only lands silently in the shade
    // instead of popping up as a heads-up banner.
    android: { priority: "high", notification: { channelId: "high_importance_channel" } },
  });

  // Prune tokens FCM says are no longer valid (app uninstalled, token
  // rotated, etc) so future sends don't keep paying for a dead lookup.
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
    await prisma.client.deviceToken.deleteMany({ where: { id: { in: staleIds } } });
  }
}
