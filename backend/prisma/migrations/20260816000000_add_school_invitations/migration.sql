-- CreateTable
CREATE TABLE "school_invitations" (
    "id" BIGSERIAL NOT NULL,
    "school_id" BIGINT NOT NULL,
    "email" VARCHAR(128) NOT NULL,
    "role_id" INTEGER NOT NULL,
    "token" VARCHAR(64) NOT NULL,
    "invited_by" BIGINT,
    "expires_at" TIMESTAMPTZ NOT NULL,
    "used_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "school_invitations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "school_invitations_token_key" ON "school_invitations"("token");

-- AddForeignKey
ALTER TABLE "school_invitations" ADD CONSTRAINT "school_invitations_school_id_fkey" FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_invitations" ADD CONSTRAINT "school_invitations_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "school_invitations" ADD CONSTRAINT "school_invitations_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
