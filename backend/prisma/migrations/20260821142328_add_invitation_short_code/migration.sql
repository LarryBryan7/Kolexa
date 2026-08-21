-- Código corto (6 dígitos) como alias humano del token de invitación.
-- No es único a nivel de constraint (a diferencia de `token`): el espacio
-- de 1M combinaciones no alcanza para reservar códigos para siempre
-- incluso después de usados/vencidos. La unicidad real (solo entre
-- invitaciones ACTIVAS) se valida en invitations.service.ts.
ALTER TABLE "school_invitations" ADD COLUMN "short_code" VARCHAR(6);

CREATE INDEX "school_invitations_shortCode_idx" ON "school_invitations"("short_code");
