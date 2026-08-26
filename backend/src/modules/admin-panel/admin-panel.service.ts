import crypto from "crypto";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { AppError } from "../../common/errors/app-error";
import { signAdminPanelToken } from "../../common/guards/admin-panel.guard";
import { SESSION_TTL_MS } from "../sessions/sessions.service";
import {
  AdminLoginDto,
  SuspendUserDto,
  AdminUserQueryDto,
  AdminSessionQueryDto,
  AdminReportQueryDto,
} from "./admin-panel.schema";

function safeEqual(a: string, b: string): boolean {
  const bufA = crypto.createHash("sha256").update(a).digest();
  const bufB = crypto.createHash("sha256").update(b).digest();
  return crypto.timingSafeEqual(bufA, bufB);
}

const adminUserSelect = {
  id: true,
  name: true,
  email: true,
  role: true,
  avatarUrl: true,
  isSuspended: true,
  suspendedAt: true,
  suspendedReason: true,
  createdAt: true,
  _count: {
    select: {
      createdSessions: true,
      submittedReports: true,
      reportsReceived: true,
    },
  },
} as const;

export class AdminPanelService {
  constructor(private readonly prisma: PrismaService) {}

  login(dto: AdminLoginDto) {
    const validEmail = safeEqual(dto.email, process.env.ADMIN_EMAIL!);
    const validPassword = safeEqual(dto.password, process.env.ADMIN_PASSWORD!);
    if (!validEmail || !validPassword) {
      throw new AppError("Invalid email or password", 401);
    }
    return { token: signAdminPanelToken(dto.email) };
  }

  async getDashboard() {
    const now = new Date();
    const [
      totalUsers,
      suspendedUsers,
      ongoingSessions,
      upcomingSessions,
      endedSessions,
      pendingSessionReports,
      pendingUserReports,
      reviewedReports,
      dismissedReports,
    ] = await Promise.all([
      this.prisma.client.user.count(),
      this.prisma.client.user.count({ where: { isSuspended: true } }),
      this.prisma.client.session.count({
        where: {
          status: "ACTIVE",
          OR: [{ scheduledAt: null }, { scheduledAt: { lte: now } }],
        },
      }),
      this.prisma.client.session.count({
        where: { status: "ACTIVE", scheduledAt: { gt: now } },
      }),
      this.prisma.client.session.count({ where: { status: "CLOSED" } }),
      this.prisma.client.report.count({
        where: { status: "PENDING", targetType: "SESSION" },
      }),
      this.prisma.client.report.count({
        where: { status: "PENDING", targetType: "USER" },
      }),
      this.prisma.client.report.count({ where: { status: "REVIEWED" } }),
      this.prisma.client.report.count({ where: { status: "DISMISSED" } }),
    ]);

    return {
      users: { total: totalUsers, suspended: suspendedUsers },
      sessions: {
        ongoing: ongoingSessions,
        upcoming: upcomingSessions,
        ended: endedSessions,
      },
      reports: {
        pendingSession: pendingSessionReports,
        pendingUser: pendingUserReports,
        pendingTotal: pendingSessionReports + pendingUserReports,
        reviewed: reviewedReports,
        dismissed: dismissedReports,
      },
    };
  }

  async listUsers(query: AdminUserQueryDto) {
    const { search, status, page, limit } = query;
    const skip = (page - 1) * limit;

    const where = {
      ...(status === "SUSPENDED" && { isSuspended: true }),
      ...(status === "ACTIVE" && { isSuspended: false }),
      ...(search && {
        OR: [
          { name: { contains: search, mode: "insensitive" as const } },
          { email: { contains: search, mode: "insensitive" as const } },
        ],
      }),
    };

    const [users, total] = await Promise.all([
      this.prisma.client.user.findMany({
        where,
        select: adminUserSelect,
        orderBy: { createdAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.client.user.count({ where }),
    ]);

    return { users, total, page, limit };
  }

  async suspendUser(userId: string, dto: SuspendUserDto) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: userId },
    });
    if (!user) throw new AppError("User not found", 404);

    const updated = await this.prisma.client.user.update({
      where: { id: userId },
      data: {
        isSuspended: true,
        suspendedAt: new Date(),
        suspendedReason: dto.reason ?? null,
      },
      select: adminUserSelect,
    });

    await this.prisma.client.refreshToken.deleteMany({ where: { userId } });

    if (dto.reportId) {
      await this.prisma.client.report.updateMany({
        where: { id: dto.reportId, reportedUserId: userId },
        data: { status: "REVIEWED" },
      });
    }

    return updated;
  }

  async unsuspendUser(userId: string) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: userId },
    });
    if (!user) throw new AppError("User not found", 404);

    return this.prisma.client.user.update({
      where: { id: userId },
      data: { isSuspended: false, suspendedAt: null, suspendedReason: null },
      select: adminUserSelect,
    });
  }

  async listSessions(query: AdminSessionQueryDto) {
    const { category, search, page, limit } = query;
    const skip = (page - 1) * limit;
    const now = new Date();

    const categoryWhere =
      category === "ENDED"
        ? { status: "CLOSED" as const }
        : category === "UPCOMING"
          ? { status: "ACTIVE" as const, scheduledAt: { gt: now } }
          : {
              status: "ACTIVE" as const,
              OR: [{ scheduledAt: null }, { scheduledAt: { lte: now } }],
            };

    const where = {
      ...categoryWhere,
      ...(search && {
        OR: [
          { title: { contains: search, mode: "insensitive" as const } },
          {
            creator: {
              name: { contains: search, mode: "insensitive" as const },
            },
          },
          {
            creator: {
              email: { contains: search, mode: "insensitive" as const },
            },
          },
        ],
      }),
    };

    const [sessions, total] = await Promise.all([
      this.prisma.client.session.findMany({
        where,
        select: {
          id: true,
          title: true,
          type: true,
          status: true,
          scheduledAt: true,
          createdAt: true,
          isPublic: true,
          creator: { select: { id: true, name: true, email: true } },
          _count: { select: { participants: true, messages: true } },
        },
        orderBy:
          category === "UPCOMING"
            ? { scheduledAt: "asc" }
            : { createdAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.client.session.count({ where }),
    ]);

    const withExpiry = sessions.map((s) => {
      const anchor = s.scheduledAt ?? s.createdAt;
      return {
        ...s,
        expiresAt: new Date(anchor.getTime() + SESSION_TTL_MS[s.type]),
      };
    });

    return { sessions: withExpiry, total, page, limit };
  }

  async listReports(query: AdminReportQueryDto) {
    const { targetType, status, page, limit } = query;
    const skip = (page - 1) * limit;

    const where = {
      ...(targetType && { targetType }),
      ...(status && { status }),
    };

    const [reports, total] = await Promise.all([
      this.prisma.client.report.findMany({
        where,
        select: {
          id: true,
          targetType: true,
          reason: true,
          details: true,
          status: true,
          createdAt: true,
          reporter: { select: { id: true, name: true, email: true } },
          reportedUser: {
            select: { id: true, name: true, email: true, isSuspended: true },
          },
          session: { select: { id: true, title: true, status: true } },
        },
        orderBy: { createdAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.client.report.count({ where }),
    ]);

    return { reports, total, page, limit };
  }

  async updateReportStatus(reportId: string, status: "REVIEWED" | "DISMISSED") {
    const report = await this.prisma.client.report.findUnique({
      where: { id: reportId },
    });
    if (!report) throw new AppError("Report not found", 404);

    return this.prisma.client.report.update({
      where: { id: reportId },
      data: { status },
    });
  }
}
