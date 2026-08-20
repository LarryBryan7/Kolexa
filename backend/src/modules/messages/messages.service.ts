// ============================================================
// messages.service.ts — Mensajes directos (padre ↔ profesor)
// ============================================================
// Los mensajes directos son comunicación privada de 1 a 1
// entre un padre de familia y un profesor.
//
// Diferencia con Chat (chat.service.ts):
//   Messages → mensajes formales individuales (como un email)
//              El padre le escribe al tutor sobre la conducta de su hijo.
//   Chat     → conversación en tiempo real en grupo o privada,
//              más parecida a WhatsApp. Usa Supabase Realtime.
//
// Flujo de un mensaje:
//   1. El padre escribe un mensaje al profesor (POST /messages)
//   2. El profesor lo ve en su bandeja (GET /messages/inbox)
//   3. El profesor responde (POST /messages/:id/reply)
//   4. El padre recibe notificación push y ve la respuesta
// ============================================================

import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class MessagesService {
  constructor(private readonly prisma: PrismaService) {}

  // ── send ──────────────────────────────────────────────────
  // Envía un mensaje directo de un usuario a otro.
  //
  // Hallazgo BL-7 de la auditoría: cuando el mensaje referenciaba un
  // studentId, nunca se validaba contra el remitente — permitía enviar
  // mensajes asociados a alumnos ajenos (de cualquier colegio), que luego
  // se podían enumerar vía GET /messages/sent (incluye datos del alumno).
  // Se permite si el remitente es el padre real de ese alumno
  // (userStudent) O si es personal del mismo colegio del alumno.
  async send(
    data: {
      recipientId: bigint;    // ID del destinatario
      subject: string;        // asunto del mensaje
      body: string;           // cuerpo del mensaje
      studentId?: number;     // alumno al que se refiere el mensaje (opcional)
      parentMessageId?: bigint; // si es una respuesta, ID del mensaje original
    },
    senderId: bigint,
    senderSchoolId?: bigint,
  ) {
    // Verificar que el destinatario existe
    const recipient = await this.prisma.user.findUnique({
      where: { id: data.recipientId, deletedAt: null },
    });
    if (!recipient) {
      throw new NotFoundException('Destinatario no encontrado');
    }

    if (data.studentId !== undefined) {
      const student = await this.prisma.student.findUnique({
        where: { id: data.studentId },
        select: { schoolId: true },
      });
      if (!student) throw new NotFoundException('Alumno no encontrado');

      const ownsAsParent = await this.prisma.userStudent.findFirst({
        where: { userId: senderId, studentId: data.studentId },
        select: { id: true },
      });
      if (!ownsAsParent && student.schoolId !== senderSchoolId) {
        throw new ForbiddenException('No tienes acceso a este alumno');
      }
    }

    // Crear el mensaje principal
    const message = await this.prisma.message.create({
      data: {
        senderId,
        subject: data.subject,
        body: data.body,
        studentId: data.studentId,
        parentMessageId: data.parentMessageId,
        sentAt: new Date(),
      },
    });

    // Crear el registro de destinatario (MessageRecipient)
    // Este registro rastrea si el destinatario leyó el mensaje
    await this.prisma.messageRecipient.create({
      data: {
        messageId: message.id,
        recipientId: data.recipientId,
        isRead: false,
      },
    });

    return message;
  }

  // ── getInbox ──────────────────────────────────────────────
  // Bandeja de entrada: mensajes recibidos por el usuario actual.
  // Ordenados por fecha (más reciente primero).
  async getInbox(userId: bigint, limit = 20, offset = 0) {
    const messages = await this.prisma.messageRecipient.findMany({
      where: { recipientId: userId },
      include: {
        message: {
          include: {
            sender: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                avatar: true,
              },
            },
            student: {
              select: { id: true, firstName: true, lastName: true },
            },
          },
        },
      },
      orderBy: { message: { sentAt: 'desc' } },
      take: limit,
      skip: offset,
    });

    // Contar mensajes no leídos (para el badge)
    const unreadCount = await this.prisma.messageRecipient.count({
      where: { recipientId: userId, isRead: false },
    });

    return { messages, unreadCount };
  }

  // ── getSent ───────────────────────────────────────────────
  // Bandeja de enviados: mensajes que el usuario envió.
  async getSent(userId: bigint, limit = 20, offset = 0) {
    return this.prisma.message.findMany({
      where: { senderId: userId, parentMessageId: null }, // solo mensajes originales
      include: {
        recipients: {
          include: {
            recipient: {
              select: { id: true, firstName: true, lastName: true, avatar: true },
            },
          },
        },
        student: {
          select: { firstName: true, lastName: true },
        },
      },
      orderBy: { sentAt: 'desc' },
      take: limit,
      skip: offset,
    });
  }

  // ── getThread ─────────────────────────────────────────────
  // Obtiene un mensaje y todas sus respuestas (hilo de conversación).
  async getThread(messageId: bigint, userId: bigint) {
    // Buscar el mensaje original (el que está al inicio del hilo)
    const original = await this.prisma.message.findUnique({
      where: { id: messageId },
    });
    if (!original) throw new NotFoundException('Mensaje no encontrado');

    // Verificar que el usuario tiene acceso (es el remitente o destinatario)
    const isRecipient = await this.prisma.messageRecipient.findFirst({
      where: { messageId, recipientId: userId },
    });
    if (original.senderId !== userId && !isRecipient) {
      throw new ForbiddenException('No tienes acceso a este mensaje');
    }

    // Marcar como leído si el usuario es el destinatario
    if (isRecipient && !isRecipient.isRead) {
      await this.prisma.messageRecipient.update({
        where: { id: isRecipient.id },
        data: { isRead: true, readAt: new Date() },
      });
    }

    // Obtener el hilo completo (mensaje original + respuestas)
    const thread = await this.prisma.message.findMany({
      where: {
        OR: [
          { id: messageId },                    // el mensaje original
          { parentMessageId: messageId },       // respuestas directas
        ],
      },
      include: {
        sender: {
          select: { id: true, firstName: true, lastName: true, avatar: true },
        },
        attachments: true,
      },
      orderBy: { sentAt: 'asc' }, // cronológico (más viejo primero en el hilo)
    });

    return thread;
  }

  // ── getUnreadCount ────────────────────────────────────────
  async getUnreadCount(userId: bigint) {
    const count = await this.prisma.messageRecipient.count({
      where: { recipientId: userId, isRead: false },
    });
    return { count };
  }

  // ── markAsRead ────────────────────────────────────────────
  async markAsRead(messageId: bigint, userId: bigint) {
    await this.prisma.messageRecipient.updateMany({
      where: { messageId, recipientId: userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
  }
}
