import request from "supertest";

jest.mock("../../infrastructure/database/prisma.service", () => {
  const client = {
    notification: {
      findMany: jest.fn(),
      count: jest.fn(),
      updateMany: jest.fn(),
    },
  };
  return { PrismaService: { getInstance: () => ({ client }) } };
});

import app from "../../app";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { TokenUtil } from "../../common/utils/token.util";

const client = PrismaService.getInstance().client as unknown as {
  notification: {
    findMany: jest.Mock;
    count: jest.Mock;
    updateMany: jest.Mock;
  };
};
const tokenUtil = new TokenUtil();

function bearerFor(sub: string) {
  return `Bearer ${tokenUtil.generateTokenPair({ sub, email: `${sub}@bedfordshire.ac.uk`, role: "STUDENT" }).accessToken}`;
}

afterEach(() => jest.clearAllMocks());

describe("GET /notifications", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).get("/notifications");
    expect(res.status).toBe(401);
  });

  it("returns the caller's notifications along with an unread count", async () => {
    client.notification.findMany.mockResolvedValue([
      { id: "n1", type: "CONNECTION_REQUEST", isRead: false, createdAt: new Date().toISOString() },
    ]);
    client.notification.count.mockResolvedValue(1);

    const res = await request(app).get("/notifications").set("Authorization", bearerFor("user-1"));

    expect(res.status).toBe(200);
    expect(res.body.notifications).toHaveLength(1);
    expect(res.body.unreadCount).toBe(1);
    expect(client.notification.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { recipientId: "user-1" } })
    );
  });
});

describe("PATCH /notifications/read-all", () => {
  it("rejects an unauthenticated request", async () => {
    const res = await request(app).patch("/notifications/read-all");
    expect(res.status).toBe(401);
  });

  it("marks every unread notification for the caller as read", async () => {
    client.notification.updateMany.mockResolvedValue({ count: 3 });

    const res = await request(app)
      .patch("/notifications/read-all")
      .set("Authorization", bearerFor("user-1"));

    expect(res.status).toBe(204);
    expect(client.notification.updateMany).toHaveBeenCalledWith({
      where: { recipientId: "user-1", isRead: false },
      data: { isRead: true },
    });
  });
});
