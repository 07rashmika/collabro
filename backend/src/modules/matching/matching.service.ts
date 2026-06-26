// import { PrismaService } from "../../infrastructure/database/prisma.service";
// import { createAIProvider } from "../ai/providers/provider.factory";
// import { IAIProvider } from "../ai/providers/provider.interface";
// import { MatchingQueryDto } from "./matching.schema";
// import { StudentProfile, MatchScore, SkillWithLevel } from "./matching.types";

// const LEVEL_WEIGHT = { BEGINNER: 1, INTERMEDIATE: 2, ADVANCED: 3 };

// export class MatchingService {
//   private readonly ai: IAIProvider;

//   constructor(private readonly prisma: PrismaService) {
//     this.ai = createAIProvider();
//   }

//   async getSuggestions(userId: string, query: MatchingQueryDto) {
//     const { category, minScore, limit } = query;

//     // fetch requesting student's profile
//     const myProfile = await this.prisma.client.profile.findUnique({
//       where: { userId },
//       include: {
//         user: { select: { id: true, name: true, email: true } },
//         skills: {
//           include: {
//             skill: { select: { id: true, name: true, category: true } },
//           },
//         },
//       },
//     });

//     if (!myProfile) {
//       throw new Error(
//         "You need to set up your profile before getting suggestions"
//       );
//     }

//     if (myProfile.skills.length === 0) {
//       throw new Error(
//         "Add at least one skill to your profile to get suggestions"
//       );
//     }

//     // fetch all other student profiles
//     const otherProfiles = await this.prisma.client.profile.findMany({
//       where: {
//         userId: { not: userId },
//         skills: {
//           some: category
//             ? { skill: { category: { equals: category, mode: "insensitive" } } }
//             : {},
//         },
//       },
//       include: {
//         user: { select: { id: true, name: true, email: true } },
//         skills: {
//           include: {
//             skill: { select: { id: true, name: true, category: true } },
//           },
//         },
//       },
//     });

//     if (otherProfiles.length === 0) {
//       return { suggestions: [], total: 0 };
//     }

//     // build my student profile shape
//     const me: StudentProfile = {
//       userId: myProfile.userId,
//       name: myProfile.user.name,
//       email: myProfile.user.email,
//       bio: myProfile.bio,
//       learningGoal: myProfile.learningGoal,
//       teachGoal: myProfile.teachGoal,
//       skills: myProfile.skills as SkillWithLevel[],
//     };

//     // score each candidate
//     const scored: MatchScore[] = otherProfiles
//       .map((p) => {
//         const candidate: StudentProfile = {
//           userId: p.userId,
//           name: p.user.name,
//           email: p.user.email,
//           bio: p.bio,
//           learningGoal: p.learningGoal,
//           teachGoal: p.teachGoal,
//           skills: p.skills as SkillWithLevel[],
//         };

//         return this.scoreCandidate(me, candidate);
//       })
//       .filter((s) => s.totalScore >= minScore)
//       .sort((a, b) => b.totalScore - a.totalScore)
//       .slice(0, limit);

//     // send top candidates to AI for human-readable reasons
//     const withReasons = await this.attachAIReasons(me, scored);

//     return {
//       suggestions: withReasons,
//       total: withReasons.length,
//     };
//   }

//   private scoreCandidate(me: StudentProfile, candidate: StudentProfile): MatchScore {
//     const mySkillIds = new Set(me.skills.map((s) => s.skill.id));
//     const candidateSkillIds = new Set(candidate.skills.map((s) => s.skill.id));

//     // 1. skill overlap score — shared skills
//     const sharedSkillIds = [...mySkillIds].filter((id) =>
//       candidateSkillIds.has(id)
//     );
//     const skillOverlapScore =
//       mySkillIds.size > 0
//         ? (sharedSkillIds.length / mySkillIds.size) * 40
//         : 0;

//     // 2. complementary score — their ADVANCED = my BEGINNER (mentor match)
//     let complementaryScore = 0;
//     const complementarySkills: string[] = [];

//     for (const mySkill of me.skills) {
//       const candidateSkill = candidate.skills.find(
//         (s) => s.skill.id === mySkill.skill.id
//       );

//       if (candidateSkill) {
//         const myLevel = LEVEL_WEIGHT[mySkill.level];
//         const theirLevel = LEVEL_WEIGHT[candidateSkill.level];
//         const diff = theirLevel - myLevel;

//         // they are more advanced in something I want to learn
//         if (diff > 0) {
//           complementaryScore += diff * 10;
//           complementarySkills.push(mySkill.skill.name);
//         }
//       }
//     }

//     complementaryScore = Math.min(complementaryScore, 40);

//     // 3. goal alignment score — my learningGoal matches their teachGoal
//     let goalAlignmentScore = 0;

//     if (me.learningGoal && candidate.teachGoal) {
//       const myGoalWords = me.learningGoal.toLowerCase().split(" ");
//       const theirTeachWords = candidate.teachGoal.toLowerCase().split(" ");
//       const overlap = myGoalWords.filter((w) => theirTeachWords.includes(w));
//       goalAlignmentScore = Math.min((overlap.length / myGoalWords.length) * 20, 20);
//     }

//     const totalScore = skillOverlapScore + complementaryScore + goalAlignmentScore;

//     return {
//       student: candidate,
//       totalScore: Math.round(totalScore),
//       skillOverlapScore: Math.round(skillOverlapScore),
//       complementaryScore: Math.round(complementaryScore),
//       goalAlignmentScore: Math.round(goalAlignmentScore),
//       matchedSkills: sharedSkillIds.map(
//         (id) => me.skills.find((s) => s.skill.id === id)!.skill.name
//       ),
//       complementarySkills,
//       aiReason: "", // filled by attachAIReasons
//     };
//   }

//   private async attachAIReasons(
//     me: StudentProfile,
//     scored: MatchScore[]
//   ): Promise<MatchScore[]> {
//     if (scored.length === 0) return [];

//     // build a single prompt for all candidates to save API calls
//     const candidateSummaries = scored
//       .map(
//         (s, i) =>
//           `Candidate ${i + 1}: ${s.student.name}
//            Skills: ${s.student.skills.map((sk) => `${sk.skill.name} (${sk.level})`).join(", ")}
//            Teaching goal: ${s.student.teachGoal ?? "not set"}
//            Learning goal: ${s.student.learningGoal ?? "not set"}
//            Match score: ${s.totalScore}/100
//            Shared skills: ${s.matchedSkills.join(", ") || "none"}
//            Complementary skills: ${s.complementarySkills.join(", ") || "none"}`
//       )
//       .join("\n\n");

//     const prompt = `
//       You are a student collaboration matchmaker.

//       Student looking for matches:
//       Name: ${me.name}
//       Skills: ${me.skills.map((s) => `${s.skill.name} (${s.level})`).join(", ")}
//       Learning goal: ${me.learningGoal ?? "not set"}
//       Teaching goal: ${me.teachGoal ?? "not set"}

//       Candidates:
//       ${candidateSummaries}

//       For each candidate, write a single concise sentence (max 20 words) explaining
//       why they are a good match. Be specific — mention skill names and levels.

//       Return ONLY a JSON array of strings, one reason per candidate in order:
//       ["reason for candidate 1", "reason for candidate 2", ...]
//       No extra text, no markdown fences.
//     `;

//     try {
//       const result = await this.ai.summarize({ content: prompt, maxWords: 500 });

//       // the summary field will contain our JSON array
//       const reasons: string[] = JSON.parse(result.summary);

//       return scored.map((s, i) => ({
//         ...s,
//         aiReason: reasons[i] ?? "Good skill compatibility detected.",
//       }));
//     } catch {
//       // if AI fails — return scores without reasons
//       return scored.map((s) => ({
//         ...s,
//         aiReason: "Good skill compatibility detected.",
//       }));
//     }
//   }

//   async getMatchById(userId: string, targetUserId: string) {
//     const [myProfile, targetProfile] = await Promise.all([
//       this.prisma.client.profile.findUnique({
//         where: { userId },
//         include: {
//           user: { select: { id: true, name: true, email: true } },
//           skills: {
//             include: {
//               skill: { select: { id: true, name: true, category: true } },
//             },
//           },
//         },
//       }),
//       this.prisma.client.profile.findUnique({
//         where: { userId: targetUserId },
//         include: {
//           user: { select: { id: true, name: true, email: true } },
//           skills: {
//             include: {
//               skill: { select: { id: true, name: true, category: true } },
//             },
//           },
//         },
//       }),
//     ]);

//     if (!myProfile) {
//       throw new Error("Your profile is not set up yet");
//     }

//     if (!targetProfile) {
//       throw new Error("Target student profile not found");
//     }

//     const me: StudentProfile = {
//       userId: myProfile.userId,
//       name: myProfile.user.name,
//       email: myProfile.user.email,
//       bio: myProfile.bio,
//       learningGoal: myProfile.learningGoal,
//       teachGoal: myProfile.teachGoal,
//       skills: myProfile.skills as SkillWithLevel[],
//     };

//     const candidate: StudentProfile = {
//       userId: targetProfile.userId,
//       name: targetProfile.user.name,
//       email: targetProfile.user.email,
//       bio: targetProfile.bio,
//       learningGoal: targetProfile.learningGoal,
//       teachGoal: targetProfile.teachGoal,
//       skills: targetProfile.skills as SkillWithLevel[],
//     };

//     const score = this.scoreCandidate(me, candidate);
//     const [withReason] = await this.attachAIReasons(me, [score]);

//     return withReason;
//   }
// }