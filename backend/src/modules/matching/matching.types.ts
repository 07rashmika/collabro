export interface SkillWithLevel {
  skill: { id: string; name: string; category: string };
  level: "BEGINNER" | "INTERMEDIATE" | "ADVANCED";
}

export interface StudentProfile {
  userId: string;
  name: string;
  email: string;
  bio: string | null;
  learningGoal: string | null;
  teachGoal: string | null;
  skills: SkillWithLevel[];
}

export interface MatchScore {
  student: StudentProfile;
  totalScore: number;
  skillOverlapScore: number;
  complementaryScore: number;
  goalAlignmentScore: number;
  matchedSkills: string[];
  complementarySkills: string[];
  aiReason: string;
}