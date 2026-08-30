-- Bloques de horario no académicos con nombre propio (TUTORÍA, SALIDA,
-- FORMACIÓN…). Antes solo existían los tipos fijos recess/break/lunch, cuyo
-- nombre se derivaba del propio `type`; un bloque con nombre libre no tenía
-- dónde guardarlo y caía al fallback "Clase" en la vista del padre.
ALTER TABLE "schedule_blocks" ADD COLUMN "label" VARCHAR(100);
