-- AddColumn
-- googleSub: identificador único de la cuenta Google (sub del ID Token).
--   - nullable: los usuarios con email/password no tienen Google.
--   - unique: una cuenta Google = un User.
--   - asignado EXCLUSIVAMENTE por el backend tras validar el ID Token.
ALTER TABLE "users" ADD COLUMN "google_sub" VARCHAR(64);

-- CreateIndex
-- Índice único sobre google_sub (solo aplica a filas no nulas en Postgres).
CREATE UNIQUE INDEX "users_google_sub_key" ON "users"("google_sub");
