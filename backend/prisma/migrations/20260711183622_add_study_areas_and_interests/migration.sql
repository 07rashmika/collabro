-- AlterTable
ALTER TABLE "Profile" ADD COLUMN     "interests" TEXT[] DEFAULT ARRAY[]::TEXT[];

-- CreateTable
CREATE TABLE "StudyArea" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "StudyArea_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProfileStudyArea" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "studyAreaId" TEXT NOT NULL,

    CONSTRAINT "ProfileStudyArea_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "StudyArea_name_key" ON "StudyArea"("name");

-- CreateIndex
CREATE UNIQUE INDEX "ProfileStudyArea_profileId_studyAreaId_key" ON "ProfileStudyArea"("profileId", "studyAreaId");

-- AddForeignKey
ALTER TABLE "ProfileStudyArea" ADD CONSTRAINT "ProfileStudyArea_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProfileStudyArea" ADD CONSTRAINT "ProfileStudyArea_studyAreaId_fkey" FOREIGN KEY ("studyAreaId") REFERENCES "StudyArea"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
