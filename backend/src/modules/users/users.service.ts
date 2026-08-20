import fs from "fs/promises";
import path from "path";
import { PrismaService } from "../../infrastructure/database/prisma.service";
import { AppError } from "../../common/errors/app-error";
import { UpdateUserDto, UserQueryDto } from "./users.schema";
import { getConnectionStatuses } from "../connections/connections.service";
import { findMatchingCatalogTerms } from "../../common/utils/catalog-search.util";

const UPLOADS_ROOT = path.join(__dirname, "../../../uploads");

const publicUserSelect = {
  id: true,
  name: true,
  email: true,
  role: true,
  avatarUrl: true,
  createdAt: true,
  profile: {
    select: {
      bio: true,
      learningGoal: true,
      teachGoal: true,
      interests: true,
      skills: {
        select: {
          level: true,
          skill: { select: { id: true, name: true, category: true } },
        },
      },
      studyAreas: {
        select: {
          studyArea: { select: { id: true, name: true } },
        },
      },
    },
  },
  _count: {
    select: {
      notes: true,
      createdSessions: true,
    },
  },
} as const;

export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: userId },
      select: publicUserSelect,
    });

    if (!user) {
      throw new Error("User not found");
    }

    return user;
  }

  async getUserById(userId: string, callerId: string) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: userId },
      select: publicUserSelect,
    });

    if (!user) {
      throw new Error("User not found");
    }

    const connectionStatuses = await getConnectionStatuses(this.prisma, callerId, [userId]);
    return { ...user, connectionStatus: connectionStatuses.get(userId) ?? "NONE" };
  }

  /// Other students ranked by shared profile skills (weighted 2x) plus
  /// shared study areas with the caller — students studying the same things
  /// as the caller surface before others, ahead of raw signup recency.
  async getAllUsers(userId: string, query: UserQueryDto) {
    const { search, page, limit } = query;
    const skip = (page - 1) * limit;

    // A search matching a skill or study area name also pulls in students
    // who have it on their profile, even if their name/email don't mention
    // it — e.g. searching "React" surfaces everyone who lists React as a
    // skill, not just users literally named "React".
    const { skills, studyAreas } = search
      ? await findMatchingCatalogTerms(this.prisma, search)
      : { skills: [], studyAreas: [] };
    const skillIds = skills.map((s) => s.id);
    const studyAreaIds = studyAreas.map((s) => s.id);

    const where = {
      id: { not: userId },
      ...(search && {
        OR: [
          { name: { contains: search, mode: "insensitive" as const } },
          { email: { contains: search, mode: "insensitive" as const } },
          ...(skillIds.length > 0
            ? [{ profile: { skills: { some: { skillId: { in: skillIds } } } } }]
            : []),
          ...(studyAreaIds.length > 0
            ? [{ profile: { studyAreas: { some: { studyAreaId: { in: studyAreaIds } } } } }]
            : []),
        ],
      }),
    };

    const myProfile = await this.prisma.client.profile.findUnique({
      where:  { userId },
      select: {
        skills:     { select: { skillId: true } },
        studyAreas: { select: { studyAreaId: true } },
      },
    });
    const mySkillIds = new Set(myProfile?.skills.map((s) => s.skillId) ?? []);
    const myStudyAreaIds = new Set(myProfile?.studyAreas.map((s) => s.studyAreaId) ?? []);

    // Ranking needs the full matching set scored before it can be paged, so
    // this fetches everything the where-clause allows rather than a single
    // DB page — fine at this app's scale (mirrors MatchingService).
    const matches = await this.prisma.client.user.findMany({
      where,
      select:  publicUserSelect,
      orderBy: { createdAt: "desc" },
    });

    const scored = matches
      .map((user) => {
        const sharedSkills =
          user.profile?.skills.filter((s) => mySkillIds.has(s.skill.id)).length ?? 0;
        const sharedStudyAreas =
          user.profile?.studyAreas.filter((s) => myStudyAreaIds.has(s.studyArea.id)).length ?? 0;
        return { user, score: sharedSkills * 2 + sharedStudyAreas };
      })
      .sort((a, b) => b.score - a.score);

    const total = scored.length;
    const pageOfUsers = scored.slice(skip, skip + limit).map((s) => s.user);

    const connectionStatuses = await getConnectionStatuses(
      this.prisma,
      userId,
      pageOfUsers.map((u) => u.id)
    );
    const users = pageOfUsers.map((u) => ({
      ...u,
      connectionStatus: connectionStatuses.get(u.id) ?? "NONE",
    }));

    return {
      users,
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  async updateMe(userId: string, dto: UpdateUserDto) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new Error("User not found");
    }

    return this.prisma.client.user.update({
      where: { id: userId },
      data: dto,
      select: publicUserSelect,
    });
  }

  async uploadAvatar(userId: string, file: Express.Multer.File) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: userId },
      select: { avatarUrl: true },
    });

    if (!user) {
      throw new AppError("User not found", 404);
    }

    const updated = await this.prisma.client.user.update({
      where: { id: userId },
      data: { avatarUrl: `/uploads/avatars/${file.filename}` },
      select: publicUserSelect,
    });

    if (user.avatarUrl) {
      const oldPath = path.join(UPLOADS_ROOT, "avatars", path.basename(user.avatarUrl));
      await fs.unlink(oldPath).catch(() => {});
    }

    return updated;
  }

  async deleteAvatar(userId: string) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: userId },
      select: { avatarUrl: true },
    });

    if (!user) {
      throw new AppError("User not found", 404);
    }
    if (!user.avatarUrl) {
      throw new AppError("No avatar to remove", 404);
    }

    const updated = await this.prisma.client.user.update({
      where: { id: userId },
      data: { avatarUrl: null },
      select: publicUserSelect,
    });

    const oldPath = path.join(UPLOADS_ROOT, "avatars", path.basename(user.avatarUrl));
    await fs.unlink(oldPath).catch(() => {});

    return updated;
  }

  async deleteMe(userId: string) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new Error("User not found");
    }

    await this.prisma.client.user.delete({ where: { id: userId } });
  }

  // Admin only
  async deleteUser(targetUserId: string) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: targetUserId },
    });

    if (!user) {
      throw new Error("User not found");
    }

    await this.prisma.client.user.delete({ where: { id: targetUserId } });
  }
}