import { PrismaService } from "../../infrastructure/database/prisma.service";
import { AppError } from "../../common/errors/app-error";
import { CreateReportDto } from "./reports.schema";

export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  async createReport(
    sessionId: string,
    reporterId: string,
    dto: CreateReportDto,
  ) {
    const session = await this.prisma.client.session.findUnique({
      where: { id: sessionId },
      include: { participants: { select: { userId: true } } },
    });
    if (!session) throw new AppError("Session not found", 404);

    const memberIds = new Set([
      session.createdBy,
      ...session.participants.map((p) => p.userId),
    ]);
    if (!memberIds.has(reporterId)) {
      throw new AppError("You are not part of this session", 403);
    }

    let reportedUserId: string | null = null;
    if (dto.targetType === "USER") {
      reportedUserId = dto.reportedUserId!;
      if (reportedUserId === reporterId) {
        throw new AppError("You can't report yourself", 400);
      }
      if (!memberIds.has(reportedUserId)) {
        throw new AppError("Reported user is not part of this session", 400);
      }
    }

    return this.prisma.client.report.create({
      data: {
        targetType: dto.targetType,
        reporterId,
        sessionId,
        reportedUserId,
        reason: dto.reason,
        details: dto.details,
      },
    });
  }
}
