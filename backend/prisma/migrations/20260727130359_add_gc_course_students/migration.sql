-- CreateTable
CREATE TABLE "gc_course_students" (
    "id" BIGSERIAL NOT NULL,
    "course_id" BIGINT NOT NULL,
    "google_id" TEXT NOT NULL,
    "full_name" TEXT NOT NULL,
    "email" TEXT,
    "photo_url" TEXT,
    "synced_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gc_course_students_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "gc_course_students_course_id_google_id_key" ON "gc_course_students"("course_id", "google_id");

-- AddForeignKey
ALTER TABLE "gc_course_students" ADD CONSTRAINT "gc_course_students_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "gc_teacher_courses"("id") ON DELETE CASCADE ON UPDATE CASCADE;
