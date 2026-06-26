if (!process.env.ALLOWED_STUDENT_DOMAINS) {
  throw new Error(
    "[Config] ALLOWED_STUDENT_DOMAINS env variable is not set. " +
      "Add it to your .env file, e.g.: ALLOWED_STUDENT_DOMAINS=university.edu,student.ac.lk"
  );
}

export const STUDENT_EMAIL_DOMAINS: string[] = process.env.ALLOWED_STUDENT_DOMAINS
  .split(",")
  .map((d) => d.trim())
  .filter(Boolean);