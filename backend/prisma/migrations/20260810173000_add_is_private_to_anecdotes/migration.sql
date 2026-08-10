-- AlterTable: rename is_public -> is_private (semantics changed in schema)
-- The schema now uses `isPrivate` (mapped to is_private) instead of is_public.
-- Add the new column and drop the obsolete one.
ALTER TABLE "anecdotes" ADD COLUMN "is_private" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "anecdotes" DROP COLUMN "is_public";
