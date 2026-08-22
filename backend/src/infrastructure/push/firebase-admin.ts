import admin from "firebase-admin";
import fs from "fs";

let app: admin.app.App | null | undefined;

/// Lazily initializes the Firebase Admin SDK from a service account key
/// file (path given by FIREBASE_SERVICE_ACCOUNT_PATH — see .env). Returns
/// null, rather than throwing, when that's not configured, so push stays
/// a soft dependency: every other feature keeps working in an environment
/// that hasn't set Firebase up yet.
export function getFirebaseApp(): admin.app.App | null {
  if (app !== undefined) return app;

  const path = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!path || !fs.existsSync(path)) {
    console.warn(
      "FIREBASE_SERVICE_ACCOUNT_PATH not set or file not found — push notifications are disabled."
    );
    app = null;
    return app;
  }

  const serviceAccount = JSON.parse(fs.readFileSync(path, "utf-8"));
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return app;
}
