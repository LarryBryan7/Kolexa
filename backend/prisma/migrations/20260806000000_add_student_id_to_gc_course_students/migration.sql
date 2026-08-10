-- AlterTable: add optional link from GcCourseStudent to internal Student
ALTER TABLE "gc_course_students" ADD COLUMN "student_id" BIGINT;

-- AddForeignKey
ALTER TABLE "gc_course_students" ADD CONSTRAINT "gc_course_students_student_id_fkey"
  FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE SET NULL ON UPDATE CASCADE;
