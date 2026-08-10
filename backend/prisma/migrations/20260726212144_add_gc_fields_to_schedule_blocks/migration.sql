-- DropForeignKey
ALTER TABLE "schedule_blocks" DROP CONSTRAINT "schedule_blocks_classroom_id_fkey";

-- AlterTable
ALTER TABLE "schedule_blocks" ADD COLUMN     "gc_teacher_course_id" BIGINT,
ADD COLUMN     "owner_id" BIGINT,
ALTER COLUMN "classroom_id" DROP NOT NULL;

-- AddForeignKey
ALTER TABLE "schedule_blocks" ADD CONSTRAINT "schedule_blocks_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "classrooms"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "schedule_blocks" ADD CONSTRAINT "schedule_blocks_gc_teacher_course_id_fkey" FOREIGN KEY ("gc_teacher_course_id") REFERENCES "gc_teacher_courses"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "schedule_blocks" ADD CONSTRAINT "schedule_blocks_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
