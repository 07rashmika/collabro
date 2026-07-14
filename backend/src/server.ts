import "dotenv/config";

// Startup env validation
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

import app from "./app";
import { attachSignalingServer } from "./modules/sessions/signaling/signaling.gateway";

const PORT = process.env.PORT || 5000;

const httpServer = app.listen(PORT, () => {
  console.log(`Server Running on port ${PORT}`);
});

attachSignalingServer(httpServer);