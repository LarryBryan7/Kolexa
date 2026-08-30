// ============================================================
// announcements.service.ts — Lógica de Comunicados
// ============================================================
// Los comunicados son mensajes del colegio/profesor dirigidos
// a grupos de destinatarios (toda la escuela, un aula, etc.)
//
// Los comunicados usan el patrón scope_type + scope_id para
// apuntar a múltiples niveles sin tablas separadas:
//   scope_type = 'school'    + scope_id = schoolId    → toda la escuela
//   scope_type = 'classroom' + scope_id = classroomId → un aula
//   scope_type = 'course'    + scope_id = courseId    → una materia
//
// Diferencia con Mensajes (Messages):
//   Comunicados → de 1 a MUCHOS (broadcast, sin respuesta directa)
//   Mensajes    → de 1 a 1 (conversación privada bidireccional)
// ============================================================

import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AnnouncementsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── create ────────────────────────────────────────────────
  // Crea un comunicado y registra quién debe recibirlo.
  // Si scope_type = 'classroom', encontramos todos los padres del aula.
  async create(
    data: {
      title: string;
      content: string;
      scopeType: string;  // 'school' | 'classroom' | 'course'
      scopeId: number;
      schoolId: bigint;
      isPinned?: boolean; // ¿fijar en la parte superior del feed?
    },
    authorId: bigint,
  ) {
    // `_getRecipientIds` solo usa scopeType/scopeId de la entrada, no el
    // comunicado recién creado — corren en paralelo.
    const [announcement, recipientIds] = await Promise.all([
      // 1. Crear el comunicado
      this.prisma.announcement.create({
        data: {
          title: data.title,
          content: data.content,
          scopeType: data.scopeType,
          scopeId: data.scopeId,
          schoolId: data.schoolId,
          authorId,
          isPinned: data.isPinned ?? false,
          publishedAt: new Date(), // publicado inmediatamente
        },
      }),
      // 2. Determinar los usuarios que deben recibir el comunicado
      //    (los registros de lectura, todos 'no leído', se crean abajo)
      this._getRecipientIds(data.scopeType, data.scopeId),
    ]);

    if (recipientIds.length > 0) {
      // createMany inserta todos los registros en una sola query SQL
      // (mucho más eficiente que crear uno por uno en un loop)
      await this.prisma.announcementRead.createMany({
        data: recipientIds.map((userId) => ({
          announcementId: announcement.id,
          userId,
          isRead: false,
        })),
        skipDuplicates: true, // si ya existe un registro, no lo duplica
      });
    }

    return announcement;
  }

  // ── getFeed ───────────────────────────────────────────────
  // Obtiene el feed de comunicados para un usuario (padre/profesor).
  // Solo muestra comunicados dirigidos a su escuela/aulas.
  //
  // Parámetros:
  //   userId   → para marcar cuáles ya leyó
  //   schoolId → para filtrar por escuela
  //   limit/offset → paginación
  async getFeed(
    userId: bigint,
    schoolId: bigint | number,
    limit = 20,
    offset = 0,
  ) {
    // El conteo de no leídos no depende de la lista de comunicados (ni al
    // revés) — corren en paralelo en vez de uno tras otro.
    const [announcements, unreadCount] = await Promise.all([
      // Obtener los comunicados que el usuario debe ver,
      // incluyendo si ya los leyó o no
      this.prisma.announcement.findMany({
        where: {
          // Comunicados de la escuela del usuario
          OR: [
            { scopeType: 'school', scopeId: schoolId },
            // En el futuro, agregar filtro por aulas del usuario
          ],
          publishedAt: { not: null }, // solo los publicados
          deletedAt: null,
        },
        include: {
          author: {
            select: { firstName: true, lastName: true, avatar: true },
          },
          readRecords: {
            where: { userId }, // solo el registro de lectura de ESTE usuario
            select: { isRead: true, readAt: true },
          },
          _count: { select: { attachments: true } },
        },
        orderBy: [
          { isPinned: 'desc' }, // fijados primero
          { publishedAt: 'desc' }, // más recientes primero
        ],
        take: limit,
        skip: offset,
      }),
      // Contar no leídos (para el badge en la campanita)
      this.prisma.announcementRead.count({
        where: { userId, isRead: false },
      }),
    ]);

    return { announcements, unreadCount };
  }

  // ── markAsRead ────────────────────────────────────────────
  // Marca un comunicado como leído por el usuario actual.
  // Se llama automáticamente cuando el usuario abre el comunicado.
  async markAsRead(announcementId: bigint, userId: bigint) {
    return this.prisma.announcementRead.updateMany({
      where: { announcementId, userId, isRead: false },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });
  }

  // ── markAllAsRead ─────────────────────────────────────────
  // El usuario marca todos los comunicados como leídos
  async markAllAsRead(userId: bigint) {
    return this.prisma.announcementRead.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
  }

  // ── getById ───────────────────────────────────────────────
  async getById(announcementId: bigint) {
    const announcement = await this.prisma.announcement.findUnique({
      where: { id: announcementId, deletedAt: null },
      include: {
        author: {
          select: { firstName: true, lastName: true, avatar: true },
        },
        attachments: true,
      },
    });

    if (!announcement) {
      throw new NotFoundException('Comunicado no encontrado');
    }

    return announcement;
  }

  // ── delete ────────────────────────────────────────────────
  async delete(announcementId: bigint, userId: bigint) {
    const announcement = await this.prisma.announcement.findUnique({
      where: { id: announcementId, deletedAt: null },
    });
    if (!announcement) throw new NotFoundException('Comunicado no encontrado');
    if (announcement.authorId !== userId) {
      throw new ForbiddenException('No tienes permiso para eliminar este comunicado');
    }

    return this.prisma.announcement.update({
      where: { id: announcementId },
      data: { deletedAt: new Date() },
    });
  }

  // ── _getRecipientIds (privado) ────────────────────────────
  // Encuentra todos los IDs de usuarios que deben recibir el comunicado
  // según el scope (escuela, aula, materia).
  private async _getRecipientIds(
    scopeType: string,
    scopeId: number,
  ): Promise<bigint[]> {
    if (scopeType === 'classroom') {
      // Obtener todos los padres de los alumnos del aula
      const currentYear = new Date().getFullYear();
      const enrollments = await this.prisma.studentEnrollment.findMany({
        where: { classroomId: scopeId, academicYear: currentYear, isActive: true },
        include: {
          student: {
            include: {
              parents: { select: { userId: true } }, // UserStudent
            },
          },
        },
      });

      // Extraer IDs únicos de padres (un padre puede tener varios hijos en el aula)
      const parentIds = new Set<bigint>();
      for (const enrollment of enrollments) {
        for (const parent of enrollment.student.parents) {
          parentIds.add(parent.userId);
        }
      }
      return Array.from(parentIds);
    }

    // Para scope_type = 'school', se crearía un job en background
    // porque puede haber miles de usuarios — no bloqueamos la petición.
    // Por ahora retornamos vacío y se haría con una cola de mensajes (BullMQ).
    return [];
  }
}
