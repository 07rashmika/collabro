-- AlterTable
ALTER TABLE "PasswordResetToken"
  ADD COLUMN "verifiedAt" TIMESTAMP(3),
  ADD COLUMN "resetTokenHash" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "PasswordResetToken_resetTokenHash_key" ON "PasswordResetToken"("resetTokenHash");
