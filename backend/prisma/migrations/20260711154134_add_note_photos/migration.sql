-- CreateTable
CREATE TABLE "NotePhoto" (
    "id" TEXT NOT NULL,
    "noteId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NotePhoto_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "NotePhoto" ADD CONSTRAINT "NotePhoto_noteId_fkey" FOREIGN KEY ("noteId") REFERENCES "Note"("id") ON DELETE CASCADE ON UPDATE CASCADE;
