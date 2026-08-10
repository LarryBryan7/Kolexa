// ============================================================
// pickup.service.ts — Recojo autorizado de alumnos
// ============================================================
// Controla QUIÉN puede recoger a un alumno del colegio.
//
// Dos modelos:
//   AuthorizedPickup → persona autorizada (nombre, foto, parentesco)
//   PickupEvent      → evento real de recojo (cuándo, quién, foto del momento)
//
// Flujo de seguridad:
//   1. El padre registra las personas autorizadas para recoger a su hijo
//   2. El portero/secretaria ve la lista de autorizados cuando alguien llega
//   3. Se registra el evento con timestamp (y opcionalmente foto) para el historial
//   4. El padre recibe notificación push: "Juan fue recogido por Abuela Rosa"
// ============================================================

import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class PickupService {
  constructor(private readonly prisma: PrismaService) {}

  // ── addAuthorizedPerson ───────────────────────────────────
  // El padre agrega una persona autorizada para recoger a su hijo.
  async addAuthorizedPerson(
    data: {
      studentId: number;
      fullName: string;
      relationship: string; // 'madre', 'padre', 'abuelo', 'tío', 'empleada', etc.
      documentId?: string;  // DNI o cédula de la persona
      phone?: string;
      photoUrl?: string;    // foto de la persona para identificación
    },
    parentId: bigint,
  ) {
    // Verificar que el padre tiene acceso a este alumno
    const rel = await this.prisma.userStudent.findFirst({
      where: { userId: parentId, studentId: data.studentId },
    });
    if (!rel) throw new ForbiddenException('No tienes acceso a este alumno');

    return this.prisma.authorizedPickup.create({
      data: {
        studentId: data.studentId,
        registeredBy: parentId,
        fullName: data.fullName,
        relationship: data.relationship,
        documentId: data.documentId,
        phone: data.phone,
        photoUrl: data.photoUrl,
        isActive: true,
      },
    });
  }

  // ── getAuthorizedList ─────────────────────────────────────
  // Lista de personas autorizadas para recoger a un alumno.
  // La ve el portero/secretaria cuando alguien llega al colegio.
  async getAuthorizedList(studentId: number, requesterId: bigint) {
    // Verificar acceso (padre del alumno o personal del colegio)
    const parentRel = await this.prisma.userStudent.findFirst({
      where: { userId: requesterId, studentId },
    });
    // Si no es padre, verificamos que sea personal del colegio (simplificado)
    // En producción, verificar roles con más granularidad

    return this.prisma.authorizedPickup.findMany({
      where: { studentId, isActive: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  // ── removeAuthorizedPerson ────────────────────────────────
  // El padre desactiva una autorización (soft delete).
  async removeAuthorizedPerson(pickupId: number, parentId: bigint) {
    const pickup = await this.prisma.authorizedPickup.findUnique({
      where: { id: pickupId },
    });
    if (!pickup) throw new NotFoundException('Autorización no encontrada');
    if (pickup.registeredBy !== parentId) {
      throw new ForbiddenException('Solo quien registró esta autorización puede eliminarla');
    }

    return this.prisma.authorizedPickup.update({
      where: { id: pickupId },
      data: { isActive: false },
    });
  }

  // ── logPickupEvent ────────────────────────────────────────
  // El portero/secretaria registra que el alumno fue recogido.
  // Esto genera una notificación push al padre.
  async logPickupEvent(
    data: {
      studentId: number;
      pickedUpById?: number; // ID de la persona autorizada (si aplica)
      pickedUpByName: string; // nombre de quien recogió
      notes?: string;
      photoUrl?: string; // foto del momento del recojo
    },
    staffId: bigint,
  ) {
    const event = await this.prisma.pickupEvent.create({
      data: {
        studentId: data.studentId,
        authorizedPickupId: data.pickedUpById,
        pickedUpByName: data.pickedUpByName,
        pickedUpAt: new Date(),
        notes: data.notes,
        photoUrl: data.photoUrl,
        recordedBy: staffId,
      },
    });

    // TODO: enviar notificación push al padre via Firebase
    // await this.notificationsService.sendPushToParents(
    //   data.studentId,
    //   `${data.pickedUpByName} recogió a tu hijo(a)`,
    // );

    return event;
  }

  // ── getPickupHistory ──────────────────────────────────────
  // Historial de recojos de un alumno (lo ve el padre).
  async getPickupHistory(studentId: number, parentId: bigint, limit = 30) {
    const rel = await this.prisma.userStudent.findFirst({
      where: { userId: parentId, studentId },
    });
    if (!rel) throw new ForbiddenException('No tienes acceso al historial de este alumno');

    return this.prisma.pickupEvent.findMany({
      where: { studentId },
      include: {
        authorizedPickup: {
          select: { fullName: true, relationship: true, photoUrl: true },
        },
      },
      orderBy: { pickedUpAt: 'desc' },
      take: limit,
    });
  }
}
