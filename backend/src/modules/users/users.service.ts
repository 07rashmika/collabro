import { PrismaService } from "../../infrastructure/database/prisma.service";
import { UpdateUserDto, UserQueryDto } from "./users.schema";

const publicUserSelect = {
  id: true,
  name: true,
  email: true,
  role: true,
  createdAt: true,
  profile: {
    select: {
      bio: true,
      learningGoal: true,
      teachGoal: true,
      skills: {
        select: {
          level: true,
          skill: { select: { id: true, name: true, category: true } },
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

  async getUserById(userId: string) {
    const user = await this.prisma.client.user.findUnique({
      where: { id: userId },
      select: publicUserSelect,
    });

    if (!user) {
      throw new Error("User not found");
    }

    return user;
  }

  async getAllUsers(query: UserQueryDto) {
    const { search, page, limit } = query;
    const skip = (page - 1) * limit;

    const where = {
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
        select: publicUserSelect,
        orderBy: { createdAt: "desc" },
        skip,
        take: limit,
      }),
      this.prisma.client.user.count({ where }),
    ]);

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