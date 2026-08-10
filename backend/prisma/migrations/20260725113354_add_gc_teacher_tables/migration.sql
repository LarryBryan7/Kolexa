-- CreateTable
CREATE TABLE "gc_teacher_courses" (
    "id" BIGSERIAL NOT NULL,
    "teacher_id" BIGINT NOT NULL,
    "google_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "section" TEXT,
    "synced_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gc_teacher_courses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gc_teacher_submissions" (
    "id" BIGSERIAL NOT NULL,
    "course_id" BIGINT NOT NULL,
    "coursework_google_id" TEXT NOT NULL,
    "coursework_title" TEXT NOT NULL,
    "student_google_id" TEXT NOT NULL,
    "student_name" TEXT,
    "state" TEXT NOT NULL,
    "submitted_at" TIMESTAMPTZ,
    "synced_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gc_teacher_submissions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "gc_teacher_courses_teacher_id_google_id_key" ON "gc_teacher_courses"("teacher_id", "google_id");

-- CreateIndex
CREATE UNIQUE INDEX "gc_teacher_submissions_course_id_coursework_google_id_stude_key" ON "gc_teacher_submissions"("course_id", "coursework_google_id", "student_google_id");

-- AddForeignKey
ALTER TABLE "gc_teacher_courses" ADD CONSTRAINT "gc_teacher_courses_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gc_teacher_submissions" ADD CONSTRAINT "gc_teacher_submissions_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "gc_teacher_courses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
