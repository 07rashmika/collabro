import { ConnectionsService } from "../connections.service";
import { sendPushToUser } from "../../notifications/push.service";
import { notifyUsers } from "../../sessions/signaling/user-registry";
import { createMockPrismaService, mockModel } from "../../../test-helpers/mock-prisma";

jest.mock("../../notifications/push.service");
jest.mock("../../sessions/signaling/user-registry");

const mockedSendPush = sendPushToUser as jest.MockedFunction<typeof sendPushToUser>;
const mockedNotifyUsers = notifyUsers as jest.MockedFunction<typeof notifyUsers>;

function makeService(overrides: {
  connectionFindFirst?: unknown;
  connectionFindUnique?: unknown;
  userFindUnique?: unknown;
}) {
  const connection = mockModel({
    findFirst: jest.fn().mockResolvedValue(overrides.connectionFindFirst ?? null),
    findUnique: jest.fn().mockResolvedValue(overrides.connectionFindUnique ?? null),
    create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ id: "conn-new", ...data })),
    update: jest.fn().mockImplementation(({ where, data }) => Promise.resolve({ id: where.id, ...data })),
    delete: jest.fn().mockResolvedValue({}),
  });
  const user = mockModel({
    findUnique: jest.fn().mockResolvedValue(overrides.userFindUnique ?? { name: "Jane" }),
  });
  const notification = mockModel({
    create: jest.fn().mockResolvedValue({}),
    deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
    updateMany: jest.fn().mockResolvedValue({ count: 0 }),
  });
  const prisma = createMockPrismaService({ connection, user, notification });
  return { service: new ConnectionsService(prisma), connection, user, notification };
}

describe("ConnectionsService.sendRequest", () => {
  afterEach(() => jest.clearAllMocks());

  it("rejects connecting with yourself", async () => {
    const { service } = makeService({});
    await expect(
      service.sendRequest("user-1", { addresseeId: "user-1" })
    ).rejects.toMatchObject({ statusCode: 400 });
  });

  it("throws 404 when the addressee doesn't exist", async () => {
    const { service, user } = makeService({});
    (user.findUnique as jest.Mock).mockResolvedValue(null);

    await expect(
      service.sendRequest("user-1", { addresseeId: "user-2" })
    ).rejects.toMatchObject({ statusCode: 404 });
  });

  it("creates a PENDING connection, persists a notification, and pushes the addressee", async () => {
    const { service, connection } = makeService({});

    const result = await service.sendRequest("user-1", { addresseeId: "user-2" });

    expect(connection.create).toHaveBeenCalledWith({
      data: { requesterId: "user-1", addresseeId: "user-2", status: "PENDING" },
    });
    expect(result.status).toBe("PENDING");
    expect(mockedNotifyUsers).toHaveBeenCalledWith(["user-2"], expect.anything());
    expect(mockedSendPush).toHaveBeenCalledWith(
      expect.anything(),
      "user-2",
      "connections",
      expect.objectContaining({ data: expect.objectContaining({ type: "CONNECTION_REQUEST" }) })
    );
  });

  it("rejects a duplicate request from the same requester with 409", async () => {
    const { service } = makeService({
      connectionFindFirst: { id: "conn-1", requesterId: "user-1", addresseeId: "user-2", status: "PENDING" },
    });

    await expect(
      service.sendRequest("user-1", { addresseeId: "user-2" })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it("rejects requesting someone already connected with 409", async () => {
    const { service } = makeService({
      connectionFindFirst: { id: "conn-1", requesterId: "user-2", addresseeId: "user-1", status: "ACCEPTED" },
    });

    await expect(
      service.sendRequest("user-1", { addresseeId: "user-2" })
    ).rejects.toMatchObject({ statusCode: 409 });
  });

  it("auto-accepts when the other side already sent a pending request (mutual interest)", async () => {
    const { service, connection } = makeService({
      connectionFindFirst: { id: "conn-1", requesterId: "user-2", addresseeId: "user-1", status: "PENDING" },
      connectionFindUnique: { id: "conn-1", requesterId: "user-2", addresseeId: "user-1", status: "PENDING" },
    });

    const result = await service.sendRequest("user-1", { addresseeId: "user-2" });

    expect(connection.update).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: "conn-1" }, data: { status: "ACCEPTED" } })
    );
    expect(result.status).toBe("ACCEPTED");
  });

  it("lets a DECLINED connection be re-requested in the new direction", async () => {
    const { service, connection } = makeService({
      connectionFindFirst: { id: "conn-1", requesterId: "user-2", addresseeId: "user-1", status: "DECLINED" },
    });

    await service.sendRequest("user-1", { addresseeId: "user-2" });

    expect(connection.update).toHaveBeenCalledWith({
      where: { id: "conn-1" },
      data: { requesterId: "user-1", addresseeId: "user-2", status: "PENDING" },
    });
  });
});

describe("ConnectionsService.accept / decline", () => {
  afterEach(() => jest.clearAllMocks());

  it("rejects accept when the caller isn't the addressee", async () => {
    const { service } = makeService({
      connectionFindUnique: { id: "conn-1", requesterId: "user-2", addresseeId: "user-3", status: "PENDING" },
    });

    await expect(service.accept("conn-1", "user-1")).rejects.toMatchObject({ statusCode: 403 });
  });

  it("rejects accept when the request is no longer pending", async () => {
    const { service } = makeService({
      connectionFindUnique: { id: "conn-1", requesterId: "user-2", addresseeId: "user-1", status: "DECLINED" },
    });

    await expect(service.accept("conn-1", "user-1")).rejects.toMatchObject({ statusCode: 409 });
  });

  it("accepts a pending request and pushes only the original requester", async () => {
    const { service } = makeService({
      connectionFindUnique: { id: "conn-1", requesterId: "user-2", addresseeId: "user-1", status: "PENDING" },
    });

    const result = await service.accept("conn-1", "user-1");

    expect(result.status).toBe("ACCEPTED");
    expect(mockedSendPush).toHaveBeenCalledWith(
      expect.anything(),
      "user-2",
      "connections",
      expect.objectContaining({ data: expect.objectContaining({ type: "CONNECTION_ACCEPTED" }) })
    );
    expect(mockedSendPush).toHaveBeenCalledTimes(1);
  });

  it("declines a pending request without sending a push", async () => {
    const { service } = makeService({
      connectionFindUnique: { id: "conn-1", requesterId: "user-2", addresseeId: "user-1", status: "PENDING" },
    });

    const result = await service.decline("conn-1", "user-1");

    expect(result.status).toBe("DECLINED");
    expect(mockedSendPush).not.toHaveBeenCalled();
  });
});
