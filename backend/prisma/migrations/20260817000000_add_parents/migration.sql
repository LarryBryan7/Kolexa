-- CreateTable
CREATE TABLE "parents" (
    "id" BIGSERIAL NOT NULL,
    "school_id" BIGINT NOT NULL,
    "user_id" BIGINT,
    "first_name" VARCHAR(255) NOT NULL,
    "last_name" VARCHAR(255),
    "dni" VARCHAR(20),
    "phone" VARCHAR(20),
    "email" VARCHAR(128),
    "link_status" VARCHAR(20) NOT NULL DEFAULT 'pending',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "parents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "parent_students" (
    "id" BIGSERIAL NOT NULL,
    "parent_id" BIGINT NOT NULL,
    "student_id" BIGINT NOT NULL,
    "relationship" VARCHAR(50),
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "parent_students_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
-- user_id NO es único: un User (cuenta) puede ser padre en varios colegios,
-- por lo que puede tener varios perfiles Parent (uno por colegio).
CREATE INDEX "parents_user_id_idx" ON "parents"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "parents_school_id_dni_key" ON "parents"("school_id", "dni");

-- CreateIndex
CREATE INDEX "parents_school_id_is_active_idx" ON "parents"("school_id", "is_active");

-- CreateIndex
CREATE UNIQUE INDEX "parent_students_parent_id_student_id_key" ON "parent_students"("parent_id", "student_id");

-- CreateIndex
CREATE INDEX "parent_students_student_id_idx" ON "parent_students"("student_id");

-- AddForeignKey
ALTER TABLE "parents" ADD CONSTRAINT "parents_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parents" ADD CONSTRAINT "parents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parent_students" ADD CONSTRAINT "parent_students_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "parents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "parent_students" ADD CONSTRAINT "parent_students_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
