-- Reemplaza los dos sistemas de mensajería previos (Message/MessageRecipient
-- tipo correo, Conversation/ChatMessage tipo chat) por un solo modelo de
-- hilos con contexto escolar. Ver auditoría de mensajería del 30-08-2026:
-- ninguno de los dos validaba el colegio del destinatario, y `chat` estaba
-- desconectado de la app (código muerto en el cliente Flutter).
--
-- Volumen real en DEV al momento de esta migración: 1 message, 0
-- message_recipients, 2 conversations, 1 chat_message. Se descarta ese dato
-- de prueba en vez de migrarlo.

-- 1. Adjuntos huérfanos de mensajería (vacíos, sin código que los use).
DROP TABLE IF EXISTS "message_attachments";

-- 2. Sistema tipo correo.
DROP TABLE IF EXISTS "message_recipients";
DROP TABLE IF EXISTS "messages";

-- 3. Sistema tipo chat (desconectado de la app).
DROP TABLE IF EXISTS "chat_messages";
DROP TABLE IF EXISTS "conversation_participants";
DROP TABLE IF EXISTS "conversations";

-- 4. Nuevo modelo de hilos.
CREATE TABLE "threads" (
    "id" BIGSERIAL NOT NULL,
    "school_id" BIGINT NOT NULL,
    "kind" VARCHAR(20) NOT NULL DEFAULT 'direct',
    "subject" VARCHAR(255),
    "student_id" BIGINT,
    "priority" VARCHAR(10) NOT NULL DEFAULT 'normal',
    "last_message_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "closed_at" TIMESTAMPTZ,
    CONSTRAINT "threads_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "thread_participants" (
    "thread_id" BIGINT NOT NULL,
    "user_id" BIGINT NOT NULL,
    "last_read_at" TIMESTAMPTZ,
    "muted_at" TIMESTAMPTZ,
    "joined_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "thread_participants_pkey" PRIMARY KEY ("thread_id", "user_id")
);

CREATE TABLE "thread_messages" (
    "id" BIGSERIAL NOT NULL,
    "thread_id" BIGINT NOT NULL,
    "sender_id" BIGINT NOT NULL,
    "body" TEXT NOT NULL,
    "sent_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "edited_at" TIMESTAMPTZ,
    "deleted_at" TIMESTAMPTZ,
    CONSTRAINT "thread_messages_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "threads_school_id_last_message_at_idx" ON "threads"("school_id", "last_message_at");
CREATE INDEX "threads_student_id_idx" ON "threads"("student_id");
CREATE INDEX "thread_participants_user_id_last_read_at_idx" ON "thread_participants"("user_id", "last_read_at");
CREATE INDEX "thread_messages_thread_id_sent_at_idx" ON "thread_messages"("thread_id", "sent_at");

ALTER TABLE "threads" ADD CONSTRAINT "threads_school_id_fkey"
    FOREIGN KEY ("school_id") REFERENCES "schools"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "threads" ADD CONSTRAINT "threads_student_id_fkey"
    FOREIGN KEY ("student_id") REFERENCES "students"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "thread_participants" ADD CONSTRAINT "thread_participants_thread_id_fkey"
    FOREIGN KEY ("thread_id") REFERENCES "threads"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "thread_participants" ADD CONSTRAINT "thread_participants_user_id_fkey"
    FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "thread_messages" ADD CONSTRAINT "thread_messages_thread_id_fkey"
    FOREIGN KEY ("thread_id") REFERENCES "threads"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "thread_messages" ADD CONSTRAINT "thread_messages_sender_id_fkey"
    FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
