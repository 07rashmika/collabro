export interface PublicUser {
  id:        string;
  name:      string;
  email:     string;
  role:      string;
  createdAt: Date;
  profile: {
    bio:          string | null;
    learningGoal: string | null;
    teachGoal:    string | null;
    skills: Array<{
      level: "BEGINNER" | "INTERMEDIATE" | "ADVANCED";
      skill: { id: string; name: string; category: string };
    }>;
  } | null;
  _count: {
    notes:           number;
    createdSessions: number;
  };
}