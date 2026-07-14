-- Rename passwordHash -> encryptedPassword. Old values were bcrypt hashes
-- (one-way) and cannot be decrypted as AES-GCM ciphertext, so clear them —
-- those sessions simply go back to "no password" rather than becoming
-- permanently unjoinable.
ALTER TABLE "Session" RENAME COLUMN "passwordHash" TO "encryptedPassword";
UPDATE "Session" SET "encryptedPassword" = NULL;

ALTER TABLE "Session" ADD COLUMN "isPublic" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "SessionTag" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "skillId" TEXT NOT NULL,

    CONSTRAINT "SessionTag_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "SessionTag_sessionId_skillId_key" ON "SessionTag"("sessionId", "skillId");

ALTER TABLE "SessionTag" ADD CONSTRAINT "SessionTag_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SessionTag" ADD CONSTRAINT "SessionTag_skillId_fkey" FOREIGN KEY ("skillId") REFERENCES "Skill"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "SavedSession" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SavedSession_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "SavedSession_userId_sessionId_key" ON "SavedSession"("userId", "sessionId");

ALTER TABLE "SavedSession" ADD CONSTRAINT "SavedSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "SavedSession" ADD CONSTRAINT "SavedSession_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;
