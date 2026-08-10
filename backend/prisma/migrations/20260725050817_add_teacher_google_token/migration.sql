-- CreateTable
CREATE TABLE "teacher_google_tokens" (
    "id" BIGSERIAL NOT NULL,
    "user_id" BIGINT NOT NULL,
    "access_token" TEXT NOT NULL,
    "refresh_token" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "scope" TEXT NOT NULL,
    "google_email" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,

    CONSTRAINT "teacher_google_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "teacher_google_tokens_user_id_key" ON "teacher_google_tokens"("user_id");

-- AddForeignKey
ALTER TABLE "teacher_google_tokens" ADD CONSTRAINT "teacher_google_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
