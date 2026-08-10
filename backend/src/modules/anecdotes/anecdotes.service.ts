// ============================================================
// anecdotes.service.ts — Anécdotas del alumno
// ============================================================
// Las anécdotas son observaciones del profesor sobre el
// comportamiento o situaciones especiales de un alumno.
// Son PRIVADAS: solo las ven el padre del alumno y el profesor.
//
// Ejemplos de anécdotas:
//   - "Juan tuvo un conflicto con un compañero hoy"
//   - "María demostró excelente liderazgo en el proyecto"
//   - "Notamos que Luis llega sin desayunar esta semana"
//
// Las anécdotas son valiosas porque:
//   1. Registran el desarrollo socioemocional del alumno
//   2. Alertan a los padres de situaciones que necesitan atención
//   3. Crean un historial que el tutor puede consultar
// ============================================================

import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AnecdotesService {
  constructor(private readonly prisma: PrismaService) {}

  // ── create ────────────────────────────────────────────────
  async create(
    data: {
      studentId: number;
      title: string;
      description: string;
      category?: string; // 'behavior', 'academic', 'social', 'health'
      isPrivate?: boolean; // si es privada, el padre no la ve
      date?: string;
    },
    teacherId: bigint,
  ) {
    const student = await this.prisma.student.findUnique({
      where: { id: data.studentId, deletedAt: null },
    });
    if (!student) throw new NotFoundException('Alumno no encontrado');

    return this.prisma.anecdote.create({
      data: {
        studentId: data.studentId,
        authorId: teacherId,
        title: data.title,
        description: data.description,
        category: data.category ?? 'general',
        isPrivate: data.isPrivate ?? false,
        occurredAt: data.date ? new Date(data.date) : new Date(),
      },
      include: {
        author: { select: { firstName: true, lastName: true } },
        student: { select: { firstName: true, lastName: true } },
      },
    });
  }

  // ── getForStudent ─────────────────────────────────────────
  // Anécdotas de un alumno (el padre ve las no privadas).
  async getForStudent(studentId: number, requesterId: bigint, isTeacher: boolean) {
    if (!isTeacher) {
      // Verificar que es el padre del alumno
      const rel = await this.prisma.userStudent.findFirst({
        where: { userId: requesterId, studentId },
      });
      if (!rel) throw new ForbiddenException('No tienes acceso a las anécdotas de este alumno');
    }

    return this.prisma.anecdote.findMany({
      where: {
        studentId,
        deletedAt: null,
        // Los padres solo ven anécdotas no privadas
        ...(!isTeacher && { isPrivate: false }),
      },
      include: {
        author: { select: { firstName: true, lastName: true, avatar: true } },
      },
      orderBy: { occurredAt: 'desc' },
    });
  }

  // ── delete ────────────────────────────────────────────────
  async delete(anecdoteId: number, teacherId: bigint) {
    const anecdote = await this.prisma.anecdote.findUnique({
      where: { id: anecdoteId, deletedAt: null },
    });
    if (!anecdote) throw new NotFoundException('Anécdota no encontrada');
    if (anecdote.authorId !== teacherId) {
      throw new ForbiddenException('Solo el autor puede eliminar esta anécdota');
    }

    return this.prisma.anecdote.update({
      where: { id: anecdoteId },
      data: { deletedAt: new Date() },
    });
  }
}
