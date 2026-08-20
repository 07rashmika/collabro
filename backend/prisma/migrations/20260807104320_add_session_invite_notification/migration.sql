-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'SESSION_INVITE';

-- AlterTable
ALTER TABLE "Notification" ADD COLUMN     "sessionId" TEXT;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "Session"("id") ON DELETE CASCADE ON UPDATE CASCADE;
