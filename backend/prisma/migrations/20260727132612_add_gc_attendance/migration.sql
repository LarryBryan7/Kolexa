-- CreateTable
CREATE TABLE "gc_attendance_sessions" (
    "id" BIGSERIAL NOT NULL,
    "teacher_id" BIGINT NOT NULL,
    "date" DATE NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gc_attendance_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gc_attendance_records" (
    "id" BIGSERIAL NOT NULL,
    "session_id" BIGINT NOT NULL,
    "student_id" BIGINT NOT NULL,
    "status" VARCHAR(20) NOT NULL,
    "note" TEXT,

    CONSTRAINT "gc_attendance_records_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "gc_attendance_sessions_teacher_id_date_key" ON "gc_attendance_sessions"("teacher_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "gc_attendance_records_session_id_student_id_key" ON "gc_attendance_records"("session_id", "student_id");

-- AddForeignKey
ALTER TABLE "gc_attendance_sessions" ADD CONSTRAINT "gc_attendance_sessions_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gc_attendance_records" ADD CONSTRAINT "gc_attendance_records_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "gc_attendance_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gc_attendance_records" ADD CONSTRAINT "gc_attendance_records_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "gc_course_students"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
