// ============================================================
// chat.service.ts — Chat en tiempo real (tipo WhatsApp)
// ============================================================
// El Chat usa el modelo de Conversations + ChatMessages.
// A diferencia de Messages (email formal), el chat es:
//   - Instantáneo (los mensajes llegan en tiempo real via Supabase Realtime)
//   - Grupal o privado (una Conversation puede tener N participantes)
//   - Sin asunto ni hilo formal (más informal y rápido)
//
// Supabase Realtime funciona mediante Postgres LISTEN/NOTIFY.
// Cuando se inserta un ChatMessage en la DB, Supabase emite el evento
// a todos los clientes suscritos al canal de esa conversación.
// Flutter escucha estos eventos con supabase_flutter.
//
// En NestJS solo manejamos el REST API (crear conversación, enviar mensaje).
// Los mensajes en tiempo real los gestiona Supabase directamente —
// NestJS no necesita WebSockets propios.
// ============================================================

import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  // ── getOrCreateConversation ───────────────────────────────
  // Busca una conversación privada entre dos usuarios.
  // Si no existe, la crea.
  // Patrón común en apps de chat: "getOrCreate".
  async getOrCreateConversation(userId1: bigint, userId2: bigint) {
    // Buscar una conversación existente donde ambos usuarios participan
    // La query busca conversaciones de tipo 'private' que tienen AMBOS usuarios
    const existing = await this.prisma.conversation.findFirst({
      where: {
        type: 'private',
        AND: [
          { participants: { some: { userId: userId1 } } },
          { participants: { some: { userId: userId2 } } },
        ],
      },
      include: {
        participants: {
          include: {
            user: {
              select: { id: true, firstName: true, lastName: true, avatar: true },
            },
          },
        },
        // Traer el último mensaje para mostrar en la lista de conversaciones
        messages: {
          orderBy: { sentAt: 'desc' },
          take: 1,
        },
      },
    });

    if (existing) return existing;

    // Si no existe, crear la conversación y agregar los dos participantes
    return this.prisma.conversation.create({
      data: {
        type: 'private',
        participants: {
          createMany: {
            data: [
              { userId: userId1 },
              { userId: userId2 },
            ],
          },
        },
      },
      include: {
        participants: {
          include: {
            user: {
              select: { id: true, firstName: true, lastName: true, avatar: true },
            },
          },
        },
        messages: true,
      },
    });
  }

  // ── getConversations ──────────────────────────────────────
  // Lista de conversaciones del usuario actual (como la lista de WhatsApp).
  // Muestra el último mensaje y cuántos no leídos hay.
  async getConversations(userId: bigint) {
    return this.prisma.conversation.findMany({
      where: {
        participants: { some: { userId } }, // conversaciones donde participa
        deletedAt: null,
      },
      include: {
        participants: {
          include: {
            user: {
              select: { id: true, firstName: true, lastName: true, avatar: true },
            },
          },
        },
        messages: {
          orderBy: { sentAt: 'desc' },
          take: 1, // solo el último mensaje para el preview
        },
        // Contar mensajes no leídos para el badge
        _count: {
          select: { messages: true },
        },
      },
      orderBy: { createdAt: 'desc' }, // más recientes primero
    });
  }

  // ── getMessages ───────────────────────────────────────────
  // Historial de mensajes de una conversación.
  // Los más recientes van al final (como en WhatsApp).
  async getMessages(
    conversationId: bigint,
    userId: bigint,
    limit = 50,
    before?: bigint, // para paginación hacia atrás (cargar mensajes más viejos)
  ) {
    // Verificar que el usuario es participante de esta conversación
    const participation = await this.prisma.conversationParticipant.findFirst({
      where: { conversationId, userId },
    });
    if (!participation) {
      throw new ForbiddenException('No eres participante de esta conversación');
    }

    return this.prisma.chatMessage.findMany({
      where: {
        conversationId,
        // Si se pasa 'before', solo traer mensajes anteriores a ese ID
        ...(before && { id: { lt: before } }),
        deletedAt: null,
      },
      include: {
        sender: {
          select: { id: true, firstName: true, avatar: true },
        },
      },
      orderBy: { sentAt: 'desc' }, // más reciente primero para paginación
      take: limit,
    });
  }

  // ── sendMessage ───────────────────────────────────────────
  // Envía un mensaje en una conversación.
  // Supabase Realtime distribuye el mensaje a los demás participantes
  // automáticamente al insertarse en la tabla chat_messages.
  async sendMessage(
    conversationId: bigint,
    content: string,
    senderId: bigint,
  ) {
    // Verificar que el remitente es participante
    const participation = await this.prisma.conversationParticipant.findFirst({
      where: { conversationId, userId: senderId },
    });
    if (!participation) {
      throw new ForbiddenException('No eres participante de esta conversación');
    }

    // Insertar el mensaje en la DB
    // Supabase detecta esta inserción y notifica a los clientes en tiempo real
    const message = await this.prisma.chatMessage.create({
      data: {
        conversationId,
        senderId,
        body: content,
        sentAt: new Date(),
      },
      include: {
        sender: {
          select: { id: true, firstName: true, avatar: true },
        },
      },
    });

    // Actualizar el timestamp de la última actividad (no hay updatedAt; se usa el último mensaje)

    return message;
  }

  // ── createGroupConversation ───────────────────────────────
  // Crea una conversación grupal (ej: grupo de padres del aula).
  async createGroupConversation(
    name: string,
    participantIds: bigint[],
    creatorId: bigint,
  ) {
    return this.prisma.conversation.create({
      data: {
        type: 'group',
        name,
        createdById: creatorId,
        participants: {
          createMany: {
            data: participantIds.map((userId) => ({ userId })),
          },
        },
      },
    });
  }
}
