-- AlterTable: email pasa a ser opcional (las invitaciones de Parent lo exigen
-- a nivel de aplicación; otros roles pueden no necesitarlo).
ALTER TABLE "school_invitations" ALTER COLUMN "email" DROP NOT NULL;

-- AlterTable: liga la invitación a un Parent institucional concreto.
ALTER TABLE "school_invitations" ADD COLUMN "parent_id" BIGINT;

-- CreateIndex
CREATE INDEX "school_invitations_parent_id_idx" ON "school_invitations"("parent_id");

-- AddForeignKey
ALTER TABLE "school_invitations" ADD CONSTRAINT "school_invitations_parent_id_fkey"
  FOREIGN KEY ("parent_id") REFERENCES "parents"("id") ON DELETE SET NULL ON UPDATE CASCADE;
