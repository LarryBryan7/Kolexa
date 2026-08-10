-- CreateTable
CREATE TABLE "google_tokens" (
    "id" BIGSERIAL NOT NULL,
    "student_id" BIGINT NOT NULL,
    "access_token" TEXT NOT NULL,
    "refresh_token" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "scope" TEXT NOT NULL,
    "google_email" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "google_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gc_courses" (
    "id" BIGSERIAL NOT NULL,
    "student_id" BIGINT NOT NULL,
    "google_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "section" TEXT,
    "teacher_name" TEXT,
    "synced_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gc_courses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gc_coursework" (
    "id" BIGSERIAL NOT NULL,
    "course_id" BIGINT NOT NULL,
    "google_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "due_date" TIMESTAMPTZ,
    "max_points" DOUBLE PRECISION,
    "work_type" TEXT NOT NULL,
    "state" TEXT NOT NULL DEFAULT 'PUBLISHED',
    "alternate_link" TEXT,
    "synced_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gc_coursework_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "google_tokens_student_id_key" ON "google_tokens"("student_id");

-- CreateIndex
CREATE UNIQUE INDEX "gc_courses_student_id_google_id_key" ON "gc_courses"("student_id", "google_id");

-- CreateIndex
CREATE UNIQUE INDEX "gc_coursework_course_id_google_id_key" ON "gc_coursework"("course_id", "google_id");

-- AddForeignKey
ALTER TABLE "google_tokens" ADD CONSTRAINT "google_tokens_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gc_courses" ADD CONSTRAINT "gc_courses_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gc_coursework" ADD CONSTRAINT "gc_coursework_course_id_fkey" FOREIGN KEY ("course_id") REFERENCES "gc_courses"("id") ON DELETE CASCADE ON UPDATE CASCADE;
