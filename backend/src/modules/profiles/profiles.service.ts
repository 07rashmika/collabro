import { PrismaService } from "../../infrastructure/database/prisma.service";
import {
  CreateProfileDto,
  UpdateProfileDto,
  AddSkillDto,
  RemoveSkillDto,
  AddStudyAreaDto,
  RemoveStudyAreaDto,
} from "./profiles.schema";

const profileSelect = {
  id: true,
  bio: true,
  learningGoal: true,
  teachGoal: true,
  interests: true,
  createdAt: true,
  updatedAt: true,
  user: {
    select: {
      id: true,
      name: true,
      email: true,
      avatarUrl: true,
    },
  },
  skills: {
    select: {
      level: true,
      skill: {
        select: {
          id: true,
          name: true,
          category: true,
        },
      },
    },
  },
  studyAreas: {
    select: {
      studyArea: {
        select: {
          id: true,
          name: true,
        },
      },
    },
  },
} as const;

export class ProfilesService {
  constructor(private readonly prisma: PrismaService) {}

  async getMyProfile(userId: string) {
    const profile = await this.prisma.client.profile.findUnique({
      where: { userId },
      select: profileSelect,
    });

    if (!profile) {
      throw new Error("Profile not found");
    }

    return profile;
  }

  async getProfileByUserId(userId: string) {
    const profile = await this.prisma.client.profile.findUnique({
      where: { userId },
      select: profileSelect,
    });

    if (!profile) {
      throw new Error("Profile not found");
    }

    return profile;
  }

  async createProfile(userId: string, dto: CreateProfileDto) {
    const existing = await this.prisma.client.profile.findUnique({
      where: { userId },
    });

    if (existing) {
      throw new Error("Profile already exists for this user");
    }

    const profile = await this.prisma.client.profile.create({
      data: {
        userId,
        bio: dto.bio,
        learningGoal: dto.learningGoal,
        teachGoal: dto.teachGoal,
        interests: dto.interests,
        skills: dto.skills
          ? {
              create: dto.skills.map((s) => ({
                skillId: s.skillId,
                level: s.level,
              })),
            }
          : undefined,
        studyAreas: dto.studyAreaIds
          ? {
              create: dto.studyAreaIds.map((studyAreaId) => ({ studyAreaId })),
            }
          : undefined,
      },
      select: profileSelect,
    });

    return profile;
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const existing = await this.prisma.client.profile.findUnique({
      where: { userId },
    });

    if (!existing) {
      throw new Error("Profile not found");
    }

    const profile = await this.prisma.client.profile.update({
      where: { userId },
      data: {
        bio: dto.bio,
        learningGoal: dto.learningGoal,
        teachGoal: dto.teachGoal,
        interests: dto.interests,
      },
      select: profileSelect,
    });

    return profile;
  }

  async addSkill(userId: string, dto: AddSkillDto) {
    const profile = await this.prisma.client.profile.findUnique({
      where: { userId },
    });

    if (!profile) {
      throw new Error("Profile not found — create your profile first");
    }

    const skill = await this.prisma.client.skill.findUnique({
      where: { id: dto.skillId },
    });

    if (!skill) {
      throw new Error("Skill not found");
    }

    const existing = await this.prisma.client.profileSkill.findUnique({
      where: {
        profileId_skillId: {
          profileId: profile.id,
          skillId: dto.skillId,
        },
      },
    });

    if (existing) {
      // update level if skill already added
      const updated = await this.prisma.client.profileSkill.update({
        where: {
          profileId_skillId: {
            profileId: profile.id,
            skillId: dto.skillId,
          },
        },
        data: { level: dto.level },
        select: {
          level: true,
          skill: { select: { id: true, name: true, category: true } },
        },
      });

      return updated;
    }

    const profileSkill = await this.prisma.client.profileSkill.create({
      data: {
        profileId: profile.id,
        skillId: dto.skillId,
        level: dto.level,
      },
      select: {
        level: true,
        skill: { select: { id: true, name: true, category: true } },
      },
    });

    return profileSkill;
  }

  async removeSkill(userId: string, dto: RemoveSkillDto) {
    const profile = await this.prisma.client.profile.findUnique({
      where: { userId },
    });

    if (!profile) {
      throw new Error("Profile not found");
    }

    const existing = await this.prisma.client.profileSkill.findUnique({
      where: {
        profileId_skillId: {
          profileId: profile.id,
          skillId: dto.skillId,
        },
      },
    });

    if (!existing) {
      throw new Error("Skill not on your profile");
    }

    await this.prisma.client.profileSkill.delete({
      where: {
        profileId_skillId: {
          profileId: profile.id,
          skillId: dto.skillId,
        },
      },
    });
  }

  async addStudyArea(userId: string, dto: AddStudyAreaDto) {
    const profile = await this.prisma.client.profile.findUnique({
      where: { userId },
    });

    if (!profile) {
      throw new Error("Profile not found — create your profile first");
    }

    const studyArea = await this.prisma.client.studyArea.findUnique({
      where: { id: dto.studyAreaId },
    });

    if (!studyArea) {
      throw new Error("Study area not found");
    }

    const existing = await this.prisma.client.profileStudyArea.findUnique({
      where: {
        profileId_studyAreaId: {
          profileId: profile.id,
          studyAreaId: dto.studyAreaId,
        },
      },
    });

    if (existing) {
      return this.prisma.client.profileStudyArea.findUniqueOrThrow({
        where: {
          profileId_studyAreaId: {
            profileId: profile.id,
            studyAreaId: dto.studyAreaId,
          },
        },
        select: { studyArea: { select: { id: true, name: true } } },
      });
    }

    const profileStudyArea = await this.prisma.client.profileStudyArea.create({
      data: {
        profileId: profile.id,
        studyAreaId: dto.studyAreaId,
      },
      select: { studyArea: { select: { id: true, name: true } } },
    });

    return profileStudyArea;
  }

  async removeStudyArea(userId: string, dto: RemoveStudyAreaDto) {
    const profile = await this.prisma.client.profile.findUnique({
      where: { userId },
    });

    if (!profile) {
      throw new Error("Profile not found");
    }

    const existing = await this.prisma.client.profileStudyArea.findUnique({
      where: {
        profileId_studyAreaId: {
          profileId: profile.id,
          studyAreaId: dto.studyAreaId,
        },
      },
    });

    if (!existing) {
      throw new Error("Study area not on your profile");
    }

    await this.prisma.client.profileStudyArea.delete({
      where: {
        profileId_studyAreaId: {
          profileId: profile.id,
          studyAreaId: dto.studyAreaId,
        },
      },
    });
  }

  async deleteProfile(userId: string) {
    const existing = await this.prisma.client.profile.findUnique({
      where: { userId },
    });

    if (!existing) {
      throw new Error("Profile not found");
    }

    await this.prisma.client.profile.delete({
      where: { userId },
    });
  }
}