import "dotenv/config";

// ── Startup env validation ───────────────────────────────────────────────────
const REQUIRED_ENV_VARS = [
  "DATABASE_URL",
  "JWT_ACCESS_SECRET",
  "JWT_REFRESH_SECRET",
  "ALLOWED_STUDENT_DOMAINS",
];

const missing = REQUIRED_ENV_VARS.filter((key) => !process.env[key]);
if (missing.length > 0) {
  console.error(
    `[Server] Missing required environment variables: ${missing.join(", ")}\n` +
      "Add them to your .env file and restart."
  );
  process.exit(1);
}
// ────────────────────────────────────────────────────────────────────────────

import app from "./app";

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`[Server] Running on port ${PORT}`);
});