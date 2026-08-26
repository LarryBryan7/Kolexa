// ============================================================
// appointments.service.ts — Citas entre padres y profesores
// ============================================================
// Sistema de citas con dos actores:
//   Profesor → define slots de disponibilidad (AppointmentSlot)
//   Padre    → reserva un slot (Appointment)
//
// Flujo:
//   1. Profesor crea slots disponibles: "Lunes 10:00-10:30"
//   2. Padre ve los slots disponibles y reserva uno
//   3. Se genera notificación al profesor de la reserva
//   4. El día de la cita, ambos la ven en su agenda
//   5. Después, el profesor puede marcarla como completada o cancelada
// ============================================================

import {
  Injectable,
  NotFoundException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UserPayload } from '../../common/decorators/current-user.decorator';

@Injectable()
export class AppointmentsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── createSlot ────────────────────────────────────────────
  // El profesor define cuándo está disponible para citas.
  async createSlot(
    data: {
      startTime: string; // ISO datetime: "2024-03-20T10:00:00"
      endTime: string;
      location?: string; // "Aula 3A" o "Zoom"
      maxBookings?: number; // cuántos padres pueden reservar a la vez
      schoolId?: bigint;
    },
    teacherId: bigint,
  ) {
    const start = new Date(data.startTime);
    const end = new Date(data.endTime);

    // No permitir slots en el pasado
    if (start < new Date()) {
      throw new ConflictException('No puedes crear un slot en el pasado');
    }

    // No permitir slots superpuestos del mismo profesor
    const overlap = await this.prisma.appointmentSlot.findFirst({
      where: {
        teacherId,
        OR: [
          { startTime: { lte: start }, endTime: { gte: start } },
          { startTime: { lte: end }, endTime: { gte: end } },
        ],
      },
    });
    if (overlap) {
      throw new ConflictException('Ya tienes un slot en ese horario');
    }

    return this.prisma.appointmentSlot.create({
      data: {
        teacherId,
        schoolId: data.schoolId ?? BigInt(0),
        startTime: start,
        endTime: end,
        location: data.location,
        maxBookings: data.maxBookings ?? 1,
        isAvailable: true,
      },
    });
  }

  // ── getAvailableSlots ─────────────────────────────────────
  // Todos los slots disponibles del colegio (para que el padre elija profesor).
  async getAvailableSlots(schoolId: bigint) {
    return this.prisma.appointmentSlot.findMany({
      where: {
        schoolId,
        startTime: { gte: new Date() },
        isAvailable: true,
      },
      include: {
        teacher: { select: { id: true, firstName: true, lastName: true, avatar: true } },
        _count: { select: { appointments: true } },
      },
      orderBy: { startTime: 'asc' },
    });
  }

  // ── getTeacherSlots ───────────────────────────────────────
  // Slots disponibles de un profesor (el padre los ve para reservar).
  async getTeacherSlots(teacherId: bigint, fromDate?: string) {
    const from = fromDate ? new Date(fromDate) : new Date();

    return this.prisma.appointmentSlot.findMany({
      where: {
        teacherId,
        startTime: { gte: from },
        isAvailable: true,
      },
      include: {
        teacher: { select: { id: true, firstName: true, lastName: true, avatar: true } },
        _count: { select: { appointments: true } },
      },
      orderBy: { startTime: 'asc' },
    });
  }

  // ── bookAppointment ───────────────────────────────────────
  // El padre reserva un slot disponible.
  //
  // Hallazgo BL-7 de la auditoría: studentId nunca se validaba contra el
  // padre autenticado — permitía reservar una cita citando el alumno de
  // OTRA familia, visible después vía GET /appointments/my.
  async bookAppointment(
    data: {
      slotId: number;
      studentId: number;
      reason: string; // motivo de la cita
    },
    parentId: bigint,
  ) {
    const rel = await this.prisma.userStudent.findFirst({
      where: { userId: parentId, studentId: data.studentId },
    });
    if (!rel) throw new ForbiddenException('No tienes acceso a este alumno');

    // Verificar que el slot existe y está disponible
    const slot = await this.prisma.appointmentSlot.findUnique({
      where: { id: data.slotId },
      include: { _count: { select: { appointments: true } } },
    });

    if (!slot) throw new NotFoundException('Slot no encontrado');
    if (!slot.isAvailable) throw new ConflictException('Este horario ya no está disponible');

    // Verificar que no está lleno
    if (slot._count.appointments >= slot.maxBookings) {
      throw new ConflictException('Este horario ya está lleno');
    }

    // Verificar que el padre no ya tiene una cita en este slot
    const alreadyBooked = await this.prisma.appointment.findFirst({
      where: { slotId: data.slotId, parentId },
    });
    if (alreadyBooked) {
      throw new ConflictException('Ya tienes una cita reservada en este horario');
    }

    // Crear la cita
    const appointment = await this.prisma.appointment.create({
      data: {
        slotId: data.slotId,
        parentId,
        studentId: data.studentId,
        reason: data.reason,
        status: 'scheduled',
      },
      include: {
        slot: {
          include: {
            teacher: { select: { firstName: true, lastName: true } },
          },
        },
      },
    });

    // Si el slot llegó al máximo de reservas, marcarlo como no disponible
    if (slot._count.appointments + 1 >= slot.maxBookings) {
      await this.prisma.appointmentSlot.update({
        where: { id: data.slotId },
        data: { isAvailable: false },
      });
    }

    return appointment;
  }

  // ── getMyAppointments ─────────────────────────────────────
  // Citas del usuario actual (padre ve sus citas, profesor ve las suyas).
  // El director (school_admin) ve TODAS las citas de su colegio, sin
  // importar el query param `role` — antes esto le devolvía lista vacía
  // (no había rama para su rol).
  async getMyAppointments(user: UserPayload, role: 'parent' | 'teacher') {
    const userId = user.sub;

    if (user.roles.includes('school_admin') && user.schoolId) {
      return this.prisma.appointment.findMany({
        where: { slot: { schoolId: user.schoolId } },
        include: {
          slot: { include: { teacher: { select: { firstName: true, lastName: true, avatar: true } } } },
          parent: { select: { firstName: true, lastName: true, avatar: true } },
          student: { select: { firstName: true, lastName: true } },
        },
        orderBy: { slot: { startTime: 'asc' } },
      });
    }

    if (role === 'parent') {
      return this.prisma.appointment.findMany({
        where: { parentId: userId },
        include: {
          slot: {
            include: {
              teacher: { select: { firstName: true, lastName: true, avatar: true } },
            },
          },
          student: { select: { firstName: true, lastName: true } },
        },
        orderBy: { slot: { startTime: 'asc' } },
      });
    }

    // Rol profesor: ver citas en sus slots
    return this.prisma.appointment.findMany({
      where: { slot: { teacherId: userId } },
      include: {
        slot: true,
        parent: { select: { firstName: true, lastName: true, avatar: true } },
        student: { select: { firstName: true, lastName: true } },
      },
      orderBy: { slot: { startTime: 'asc' } },
    });
  }

  // ── updateStatus ──────────────────────────────────────────
  // Actualizar el estado de una cita (completada, cancelada, etc.)
  async updateStatus(
    appointmentId: number,
    status: 'scheduled' | 'completed' | 'cancelled' | 'no_show',
    userId: bigint,
    notes?: string,
  ) {
    const appt = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: { slot: true },
    });
    if (!appt) throw new NotFoundException('Cita no encontrada');

    // Solo el padre o el profesor de la cita puede cambiar el estado
    const isParent = appt.parentId === userId;
    const isTeacher = appt.slot.teacherId === userId;
    if (!isParent && !isTeacher) {
      throw new ForbiddenException('No tienes permiso para modificar esta cita');
    }

    return this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        status,
        teacherNotes: notes,
        ...(status === 'completed' && { completedAt: new Date() }),
      },
    });
  }
}
