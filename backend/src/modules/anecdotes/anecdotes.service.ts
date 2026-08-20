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

  // ── isTeacherOfStudent ────────────────────────────────────
  // Granularidad real de autorización docente en KOLEXA (hallazgo BL-2,
  // Ronda 4): auditado el modelo — UserClassroom existe en el schema pero
  // NO se usa en ningún service (grep exhaustivo sin resultados). La
  // única relación exacta que el código YA usa para "¿este docente dicta
  // clases a este alumno?" es ClassroomCourse (aula+curso→docente) cruzada
  // con StudentEnrollment (alumno→aula, año en curso) — el mismo patrón
  // que grades.service.ts::setGrade(). Se reutiliza aquí tal cual, en vez
  // de la aproximación "mismo colegio" que dejó documentada la Ronda 3.
  //
  // Trade-off documentado: un docente que dictó a este alumno en un año
  // ANTERIOR (matrícula ya no isActive) ya no ve sus anécdotas nuevas,
  // aunque siga en el mismo colegio. Es una restricción MÁS estricta que
  // "mismo colegio", consistente con lo que ya asumía grades.service.ts.
  private async isTeacherOfStudent(teacherId: bigint, studentId: number): Promise<boolean> {
    const currentYear = new Date().getFullYear();
    const enrollment = await this.prisma.studentEnrollment.findFirst({
      where: { studentId, academicYear: currentYear, isActive: true },
      select: { classroomId: true },
    });
    if (!enrollment) return false;

    const teaches = await this.prisma.classroomCourse.findFirst({
      where: { classroomId: enrollment.classroomId, teacherId },
      select: { id: true },
    });
    return !!teaches;
  }

  // ── create ────────────────────────────────────────────────
  // Extensión de BL-2 (mismo hallazgo, mismo fix): create() no tenía
  // NINGÚN chequeo de ownership — cualquier autenticado podía crear una
  // anécdota (incluso privada) sobre cualquier alumno. Reutiliza el mismo
  // guard que getForStudent.
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

    const authorized = await this.isTeacherOfStudent(teacherId, data.studentId);
    if (!authorized) {
      throw new ForbiddenException('No dictas clases a este alumno');
    }

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
  //
  // isTeacher llega derivado del JWT (ver controller), no de un query
  // param (hallazgo BL-2, Ronda 3). Para el caso docente, la Ronda 3
  // dejó documentado "mismo colegio" como interpretación mínima interina;
  // la Ronda 4 la reemplaza por la relación exacta que ya usa
  // grades.service.ts — ver isTeacherOfStudent() arriba.
  async getForStudent(studentId: number, requesterId: bigint, isTeacher: boolean) {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { id: true },
    });
    if (!student) throw new NotFoundException('Alumno no encontrado');

    if (isTeacher) {
      const authorized = await this.isTeacherOfStudent(requesterId, studentId);
      if (!authorized) {
        throw new ForbiddenException('No tienes acceso a las anécdotas de este alumno');
      }
    } else {
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
