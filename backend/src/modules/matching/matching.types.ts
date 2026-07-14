export interface SkillWithLevel {
  skill: { id: string; name: string; category: string };
  level: "BEGINNER" | "INTERMEDIATE" | "ADVANCED";
}

export interface StudyAreaRef {
  studyArea: { id: string; name: string };
}

export interface StudentProfile {
  userId: string;
  name: string;
  email: string;
  bio: string | null;
  learningGoal: string | null;
  teachGoal: string | null;
  interests: string[];
  skills: SkillWithLevel[];
  studyAreas: StudyAreaRef[];
}

export interface MatchScore {
  student: StudentProfile;
  totalScore: number;
  skillOverlapScore: number;
  complementaryScore: number;
  goalAlignmentScore: number;
  studyAreaOverlapScore: number;
  interestOverlapScore: number;
  matchedSkills: string[];
  complementarySkills: string[];
  matchedStudyAreas: string[];
  matchedInterests: string[];
  aiReason: string;
}
