-- AlterTable: add nullable columns first
ALTER TABLE "Session" ADD COLUMN     "joinCode" TEXT;
ALTER TABLE "Session" ADD COLUMN     "passwordHash" TEXT;

-- Backfill existing rows with a unique join code
UPDATE "Session" SET "joinCode" = substr(md5(random()::text || clock_timestamp()::text || id), 1, 25) WHERE "joinCode" IS NULL;

-- Enforce NOT NULL + uniqueness now that every row has a value
ALTER TABLE "Session" ALTER COLUMN "joinCode" SET NOT NULL;
CREATE UNIQUE INDEX "Session_joinCode_key" ON "Session"("joinCode");
