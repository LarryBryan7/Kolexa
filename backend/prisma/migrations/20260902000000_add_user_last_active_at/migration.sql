-- Punto verde/gris de "en línea" en chats: se necesita saber cuándo un
-- usuario estuvo activo por última vez, sin agregar WebSocket ni tabla de
-- sesiones. Se actualiza (con throttle) en cada request autenticado.
ALTER TABLE "users" ADD COLUMN "last_active_at" TIMESTAMPTZ;
