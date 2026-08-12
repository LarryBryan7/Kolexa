-- CreateTable
CREATE TABLE "gc_student_submissions" (
    "id" BIGSERIAL NOT NULL,
    "coursework_id" BIGINT NOT NULL,
    "google_id" TEXT NOT NULL,
    "submission_state" TEXT NOT NULL,
    "assigned_grade" DOUBLE PRECISION,
    "synced_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gc_student_submissions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "gc_student_submissions_coursework_id_google_id_key" ON "gc_student_submissions"("coursework_id", "google_id");

-- AddForeignKey
ALTER TABLE "gc_student_submissions" ADD CONSTRAINT "gc_student_submissions_coursework_id_fkey" FOREIGN KEY ("coursework_id") REFERENCES "gc_coursework"("id") ON DELETE CASCADE ON UPDATE CASCADE;
