-- CreateTable
CREATE TABLE "schedule_blocks" (
    "id" BIGSERIAL NOT NULL,
    "classroom_course_id" BIGINT NOT NULL,
    "day_of_week" SMALLINT NOT NULL,
    "start_time" TIME NOT NULL,
    "end_time" TIME NOT NULL,
    "room" VARCHAR(100),

    CONSTRAINT "schedule_blocks_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "schedule_blocks" ADD CONSTRAINT "schedule_blocks_classroom_course_id_fkey" FOREIGN KEY ("classroom_course_id") REFERENCES "classroom_courses"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
