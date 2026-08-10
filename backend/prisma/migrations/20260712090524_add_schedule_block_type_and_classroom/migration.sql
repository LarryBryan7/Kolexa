-- DropForeignKey
ALTER TABLE "schedule_blocks" DROP CONSTRAINT "schedule_blocks_classroom_course_id_fkey";

-- Añadir columnas: classroom_id nullable primero para poder hacer backfill
ALTER TABLE "schedule_blocks"
  ADD COLUMN "classroom_id" BIGINT,
  ADD COLUMN "type"         VARCHAR(20) NOT NULL DEFAULT 'class',
  ALTER COLUMN "classroom_course_id" DROP NOT NULL;

-- Backfill: classroom_id desde la relación existente classroom_courses
UPDATE "schedule_blocks" sb
SET "classroom_id" = cc."classroom_id"
FROM "classroom_courses" cc
WHERE cc."id" = sb."classroom_course_id";

-- Ahora sí imponer NOT NULL
ALTER TABLE "schedule_blocks" ALTER COLUMN "classroom_id" SET NOT NULL;

-- AddForeignKey
ALTER TABLE "schedule_blocks" ADD CONSTRAINT "schedule_blocks_classroom_id_fkey" FOREIGN KEY ("classroom_id") REFERENCES "classrooms"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "schedule_blocks" ADD CONSTRAINT "schedule_blocks_classroom_course_id_fkey" FOREIGN KEY ("classroom_course_id") REFERENCES "classroom_courses"("id") ON DELETE SET NULL ON UPDATE CASCADE;
