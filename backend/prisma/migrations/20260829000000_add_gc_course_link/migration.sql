-- Puente entre un curso de Google Classroom y el curso institucional.
-- Ancla en google_course_id (no en las tablas caché gc_teacher_courses /
-- gc_courses) para sobrevivir a un borrado y re-sincronización.
CREATE TABLE "gc_course_links" (
    "id" BIGSERIAL NOT NULL,
    "school_id" BIGINT NOT NULL,
    "google_course_id" VARCHAR(64) NOT NULL,
    "classroom_course_id" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "gc_course_links_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "gc_course_links_school_id_google_course_id_key"
    ON "gc_course_links"("school_id", "google_course_id");
CREATE INDEX "gc_course_links_classroom_course_id_idx"
    ON "gc_course_links"("classroom_course_id");

ALTER TABLE "gc_course_links" ADD CONSTRAINT "gc_course_links_school_id_fkey"
    FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "gc_course_links" ADD CONSTRAINT "gc_course_links_classroom_course_id_fkey"
    FOREIGN KEY ("classroom_course_id") REFERENCES "classroom_courses"("id") ON DELETE CASCADE ON UPDATE CASCADE;
