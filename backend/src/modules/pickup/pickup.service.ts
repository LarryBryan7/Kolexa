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
import { UserPayload } from '../../common/decorators/current-user.decorator';
import { isSchoolAdminOf } from '../../common/utils/school-staff-access';

@Injectable()
export class PickupService {
  constructor(private readonly prisma: PrismaService) {}

  // ── assertParentOrStaffAccess ─────────────────────────────
  // Permite el acceso solo a: (a) el padre del alumno (userStudent), o
  // (b) personal con algún rol asignado en el mismo colegio del alumno
  // (portero/secretaria/docente/admin — el modelo actual no distingue un
  // rol específico de "portero", así que "personal de ese colegio" es la
  // interpretación mínima y segura del comentario original "verificamos
  // que sea personal del colegio (simplificado)"). Nunca confía en
  // studentId/rol enviado por el cliente más allá de resolverlo contra
  // las relaciones reales en BD.
  private async assertParentOrStaffAccess(userId: bigint, studentId: number): Promise<void> {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { schoolId: true },
    });
    if (!student) throw new NotFoundException('Alumno no encontrado');

    const isParent = await this.prisma.userStudent.findFirst({
      where: { userId, studentId },
      select: { id: true },
    });
    if (isParent) return;

    const isStaff = await this.prisma.userRole.findFirst({
      where: { userId, schoolId: student.schoolId },
      select: { id: true },
    });
    if (isStaff) return;

    throw new ForbiddenException('No tienes acceso a este alumno');
  }

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
  //
  // Hallazgo BL-4 de la auditoría: el chequeo de acceso (parentRel) se
  // CALCULABA pero nunca se APLICABA — cualquier usuario autenticado podía
  // leer nombres, teléfonos, fotos y parentesco de las personas
  // autorizadas a recoger a un alumno ajeno. Ahora sí se exige: o el
  // padre del alumno (userStudent), o personal con algún rol en el mismo
  // colegio del alumno (portero/secretaria/docente/admin).
  async getAuthorizedList(studentId: number, requesterId: bigint) {
    await this.assertParentOrStaffAccess(requesterId, studentId);

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
  //
  // Hallazgo BL-4 de la auditoría: no existía ningún chequeo de ownership
  // ni de rol — cualquier autenticado (incluido un padre ajeno) podía
  // inyectar un evento de recojo falso para cualquier alumno, contaminando
  // el sistema de seguridad física del colegio. Mismo guard que
  // getAuthorizedList: padre del alumno o personal del mismo colegio.
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
    await this.assertParentOrStaffAccess(staffId, data.studentId);

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
  // Historial de recojos de un alumno. Lo ve el padre, o el director
  // (school_admin) del mismo colegio del alumno.
  async getPickupHistory(studentId: number, user: UserPayload, limit = 30) {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { schoolId: true },
    });
    if (!student) throw new NotFoundException('Alumno no encontrado');

    if (!isSchoolAdminOf(user, student.schoolId)) {
      const rel = await this.prisma.userStudent.findFirst({
        where: { userId: user.sub, studentId },
      });
      if (!rel) throw new ForbiddenException('No tienes acceso al historial de este alumno');
    }

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
