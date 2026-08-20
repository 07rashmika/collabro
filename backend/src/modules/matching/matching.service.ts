import { PrismaService } from "../../infrastructure/database/prisma.service";
import { MatchingQueryDto } from "./matching.schema";
import { StudentProfile, MatchScore, SkillWithLevel, StudyAreaRef } from "./matching.types";
import { getConnectionStatuses } from "../connections/connections.service";

const LEVEL_WEIGHT = { BEGINNER: 1, INTERMEDIATE: 2, ADVANCED: 3 };

const profileInclude = {
  user: { select: { id: true, name: true, email: true, avatarUrl: true } },
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
} as const;

export class MatchingService {
  constructor(private readonly prisma: PrismaService) {}

  async getSuggestions(userId: string, query: MatchingQueryDto) {
    const { category, minScore, limit } = query;

    // fetch requesting student's profile
    const myProfile = await this.prisma.client.profile.findUnique({
      where: { userId },
      include: profileInclude,
    });

    if (!myProfile) {
      throw new Error(
        "You need to set up your profile before getting suggestions"
      );
    }

    if (myProfile.skills.length === 0) {
      throw new Error(
        "Add at least one skill to your profile to get suggestions"
      );
    }

    // fetch all other student profiles
    const otherProfiles = await this.prisma.client.profile.findMany({
      where: {
        userId: { not: userId },
        skills: {
          some: category
            ? { skill: { category: { equals: category, mode: "insensitive" } } }
            : {},
        },
      },
      include: profileInclude,
    });

    if (otherProfiles.length === 0) {
      return { suggestions: [], total: 0 };
    }

    // Already-connected students aren't "recommendations" anymore — filter
    // them out before scoring/limiting rather than after, so a page of
    // results isn't shrunk by candidates that get dropped downstream.
    const connectionStatuses = await getConnectionStatuses(
      this.prisma,
      userId,
      otherProfiles.map((p) => p.userId)
    );
    const candidateProfiles = otherProfiles.filter(
      (p) => connectionStatuses.get(p.userId) !== "CONNECTED"
    );

    if (candidateProfiles.length === 0) {
      return { suggestions: [], total: 0 };
    }

    const me = this.toStudentProfile(myProfile);

    // score + rank every candidate, then attach a human-readable reason
    // built directly from the score breakdown (see buildReason below)
    // A 0% match isn't a "recommendation" — always excluded regardless of
    // the requested minScore, which only raises the bar further.
    const scored: MatchScore[] = candidateProfiles
      .map((p) => this.scoreCandidate(me, this.toStudentProfile(p)))
      .filter((s) => s.totalScore > 0 && s.totalScore >= minScore)
      .sort((a, b) => b.totalScore - a.totalScore)
      .slice(0, limit)
      .map((s) => ({ ...s, aiReason: this.buildReason(s) }));

    const suggestions = scored.map((s) => ({
      ...s,
      connectionStatus: connectionStatuses.get(s.student.userId) ?? "NONE",
    }));

    return { suggestions, total: suggestions.length };
  }

  async getMatchById(userId: string, targetUserId: string) {
    const [myProfile, targetProfile] = await Promise.all([
      this.prisma.client.profile.findUnique({
        where: { userId },
        include: profileInclude,
      }),
      this.prisma.client.profile.findUnique({
        where: { userId: targetUserId },
        include: profileInclude,
      }),
    ]);

    if (!myProfile) {
      throw new Error("Your profile is not set up yet");
    }
    if (!targetProfile) {
      throw new Error("Target student profile not found");
    }

    const score = this.scoreCandidate(
      this.toStudentProfile(myProfile),
      this.toStudentProfile(targetProfile)
    );

    return { ...score, aiReason: this.buildReason(score) };
  }

  private toStudentProfile(p: {
    userId: string;
    bio: string | null;
    learningGoal: string | null;
    teachGoal: string | null;
    interests: string[];
    user: { name: string; email: string; avatarUrl: string | null };
    skills: SkillWithLevel[];
    studyAreas: StudyAreaRef[];
  }): StudentProfile {
    return {
      userId: p.userId,
      name: p.user.name,
      email: p.user.email,
      avatarUrl: p.user.avatarUrl,
      bio: p.bio,
      learningGoal: p.learningGoal,
      teachGoal: p.teachGoal,
      interests: p.interests,
      skills: p.skills,
      studyAreas: p.studyAreas,
    };
  }

  /**
   * Weighted score out of 100:
   *  - 30% shared skills (how much of my skill set they also have)
   *  - 25% complementary skills (they're more advanced than me in something I have)
   *  - 10% goal alignment (my learningGoal overlaps their teachGoal)
   *  - 20% shared study areas
   *  - 15% shared interests
   */
  private scoreCandidate(me: StudentProfile, candidate: StudentProfile): MatchScore {
    const mySkillIds = new Set(me.skills.map((s) => s.skill.id));
    const candidateSkillIds = new Set(candidate.skills.map((s) => s.skill.id));

    // 1. skill overlap score — shared skills
    const sharedSkillIds = [...mySkillIds].filter((id) =>
      candidateSkillIds.has(id)
    );
    const skillOverlapScore =
      mySkillIds.size > 0
        ? (sharedSkillIds.length / mySkillIds.size) * 30
        : 0;

    // 2. complementary score — their ADVANCED = my BEGINNER (mentor match)
    let complementaryScore = 0;
    const complementarySkills: string[] = [];

    for (const mySkill of me.skills) {
      const candidateSkill = candidate.skills.find(
        (s) => s.skill.id === mySkill.skill.id
      );

      if (candidateSkill) {
        const myLevel = LEVEL_WEIGHT[mySkill.level];
        const theirLevel = LEVEL_WEIGHT[candidateSkill.level];
        const diff = theirLevel - myLevel;

        // they are more advanced in something I want to learn
        if (diff > 0) {
          complementaryScore += diff * (25 / 4);
          complementarySkills.push(mySkill.skill.name);
        }
      }
    }

    complementaryScore = Math.min(complementaryScore, 25);

    // 3. goal alignment score — my learningGoal matches their teachGoal
    let goalAlignmentScore = 0;

    if (me.learningGoal && candidate.teachGoal) {
      const myGoalWords = me.learningGoal.toLowerCase().split(/\s+/).filter(Boolean);
      const theirTeachWords = candidate.teachGoal.toLowerCase().split(/\s+/);
      const overlap = myGoalWords.filter((w) => theirTeachWords.includes(w));
      goalAlignmentScore =
        myGoalWords.length > 0
          ? Math.min((overlap.length / myGoalWords.length) * 10, 10)
          : 0;
    }

    // 4. study area overlap score — shared fields of study
    const myStudyAreaIds = new Set(me.studyAreas.map((s) => s.studyArea.id));
    const candidateStudyAreaIds = new Set(
      candidate.studyAreas.map((s) => s.studyArea.id)
    );
    const sharedStudyAreaIds = [...myStudyAreaIds].filter((id) =>
      candidateStudyAreaIds.has(id)
    );
    const studyAreaOverlapScore =
      myStudyAreaIds.size > 0
        ? (sharedStudyAreaIds.length / myStudyAreaIds.size) * 20
        : 0;

    // 5. interest overlap score — shared interests (case-insensitive)
    const myInterests = new Set(me.interests.map((i) => i.toLowerCase().trim()));
    const candidateInterests = new Set(
      candidate.interests.map((i) => i.toLowerCase().trim())
    );
    const sharedInterests = [...myInterests].filter((i) => candidateInterests.has(i));
    const interestOverlapScore =
      myInterests.size > 0
        ? (sharedInterests.length / myInterests.size) * 15
        : 0;

    const totalScore =
      skillOverlapScore +
      complementaryScore +
      goalAlignmentScore +
      studyAreaOverlapScore +
      interestOverlapScore;

    return {
      student: candidate,
      totalScore: Math.round(totalScore),
      skillOverlapScore: Math.round(skillOverlapScore),
      complementaryScore: Math.round(complementaryScore),
      goalAlignmentScore: Math.round(goalAlignmentScore),
      studyAreaOverlapScore: Math.round(studyAreaOverlapScore),
      interestOverlapScore: Math.round(interestOverlapScore),
      matchedSkills: sharedSkillIds.map(
        (id) => me.skills.find((s) => s.skill.id === id)!.skill.name
      ),
      complementarySkills,
      matchedStudyAreas: sharedStudyAreaIds.map(
        (id) => me.studyAreas.find((s) => s.studyArea.id === id)!.studyArea.name
      ),
      matchedInterests: sharedInterests,
      aiReason: "", // filled by buildReason
    };
  }

  /**
   * Human-readable reason built directly from the score breakdown. The
   * `ai` provider module this originally called (for LLM-generated
   * reasons) doesn't exist in this codebase yet — this deterministic
   * version stands in until that's built.
   */
  private buildReason(score: MatchScore): string {
    const parts: string[] = [];

    if (score.complementarySkills.length > 0) {
      parts.push(
        `Can help you level up in ${score.complementarySkills.slice(0, 2).join(" and ")}`
      );
    }
    if (score.matchedSkills.length > 0) {
      parts.push(
        `shares ${score.matchedSkills.length} skill${score.matchedSkills.length > 1 ? "s" : ""} with you (${score.matchedSkills.slice(0, 2).join(", ")})`
      );
    }
    if (score.matchedStudyAreas.length > 0) {
      parts.push(
        `studies ${score.matchedStudyAreas.slice(0, 2).join(" and ")}`
      );
    }
    if (score.matchedInterests.length > 0) {
      parts.push(
        `into ${score.matchedInterests.slice(0, 2).join(" and ")} too`
      );
    }
    if (score.goalAlignmentScore > 0) {
      parts.push("their teaching goal lines up with what you want to learn");
    }

    if (parts.length === 0) {
      return "Good potential study partner based on your profile.";
    }
    return parts.join("; ") + ".";
  }
}
