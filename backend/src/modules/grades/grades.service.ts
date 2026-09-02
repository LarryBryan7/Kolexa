// ============================================================
// grades.service.ts — Notas y calificaciones
// ============================================================
// Gestiona las notas de los alumnos por periodo académico.
//
// Estructura de datos:
//   GradePeriod → un bimestre/trimestre/semestre
//     └── Grade  → la nota de UN alumno en UN curso en ese periodo
//
// Sistema de notas peruano: 0-20 (aprobado ≥ 11)
// El sistema también soporta escalas personalizadas por colegio.
// ============================================================

import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UserPayload } from '../../common/decorators/current-user.decorator';
import { isSchoolAdminOf } from '../../common/utils/school-staff-access';

@Injectable()
export class GradesService {
  constructor(private readonly prisma: PrismaService) {}

  // ── createPeriod ──────────────────────────────────────────
  // El coordinador crea un periodo de evaluación (bimestre, trimestre).
  async createPeriod(
    data: { name: string; startDate: string; endDate: string; schoolId: bigint; academicYear?: number },
    userId: bigint,
  ) {
    // Verificar que no exista un periodo con el mismo nombre en la misma escuela
    const existing = await this.prisma.gradePeriod.findFirst({
      where: { name: data.name, schoolId: data.schoolId },
    });
    if (existing) {
      throw new ConflictException(`Ya existe un periodo llamado "${data.name}"`);
    }

    return this.prisma.gradePeriod.create({
      data: {
        name: data.name,
        startDate: new Date(data.startDate),
        endDate: new Date(data.endDate),
        schoolId: data.schoolId,
        academicYear: data.academicYear ?? new Date().getFullYear(),
      },
    });
  }

  // ── getPeriods ────────────────────────────────────────────
  // Lista de periodos de una escuela ordenados cronológicamente.
  async getPeriods(schoolId: bigint) {
    return this.prisma.gradePeriod.findMany({
      where: { schoolId },
      orderBy: { startDate: 'asc' },
    });
  }

  // ── setGrade ──────────────────────────────────────────────
  // El profesor registra o actualiza la nota de un alumno.
  // Upsert: crea si no existe, actualiza si ya hay una nota.
  //
  // Hallazgo BL-5 de la auditoría: solo se validaba que student/course/
  // period existieran, nunca que el teacherId autenticado realmente
  // dictara ese curso — cualquier autenticado (incluido un padre) podía
  // modificar la nota de cualquier alumno de cualquier colegio. Ahora se
  // exige que exista un ClassroomCourse{classroom del alumno, course}
  // cuyo teacherId sea exactamente el usuario autenticado — esto además
  // cierra el caso cross-colegio sin necesidad de un chequeo de schoolId
  // aparte: un docente nunca está asignado como teacherId en un
  // ClassroomCourse de un colegio que no es el suyo.
  async setGrade(
    data: {
      studentId: number;
      courseId: number;
      periodId: number;
      grade: number;         // 0-20 en el sistema peruano
      gradeType?: string;    // 'numeric' | 'letter' | 'descriptive'
      observations?: string;
    },
    teacherId: bigint,
  ) {
    // Verificar que el alumno, curso y periodo existen
    const [student, course, period] = await Promise.all([
      this.prisma.student.findUnique({ where: { id: data.studentId } }),
      this.prisma.course.findUnique({ where: { id: data.courseId } }),
      this.prisma.gradePeriod.findUnique({ where: { id: data.periodId } }),
    ]);

    if (!student) throw new NotFoundException('Alumno no encontrado');
    if (!course) throw new NotFoundException('Curso no encontrado');
    if (!period) throw new NotFoundException('Periodo no encontrado');

    const currentYear = new Date().getFullYear();
    const enrollment = await this.prisma.studentEnrollment.findFirst({
      where: { studentId: data.studentId, academicYear: currentYear, isActive: true },
    });
    if (!enrollment) {
      throw new ForbiddenException('No dictas este curso a este alumno');
    }

    const classroomCourse = await this.prisma.classroomCourse.findUnique({
      where: {
        classroomId_courseId: { classroomId: enrollment.classroomId, courseId: data.courseId },
      },
    });
    if (!classroomCourse || classroomCourse.teacherId !== teacherId) {
      throw new ForbiddenException('No dictas este curso a este alumno');
    }

    return this.prisma.grade.upsert({
      where: {
        // El índice único garantiza una nota por alumno/curso/periodo
        studentId_courseId_periodId: {
          studentId: data.studentId,
          courseId: data.courseId,
          periodId: data.periodId,
        },
      },
      update: {
        grade: data.grade,
        observations: data.observations,
        gradedBy: teacherId,
        gradedAt: new Date(),
      },
      create: {
        studentId: data.studentId,
        courseId: data.courseId,
        periodId: data.periodId,
        grade: data.grade,
        gradeType: data.gradeType ?? 'numeric',
        observations: data.observations,
        gradedBy: teacherId,
        gradedAt: new Date(),
      },
    });
  }

  // ── getStudentReport ──────────────────────────────────────
  // Boleta completa de un alumno: todas sus notas por periodo y curso.
  // Lo ve el padre de familia, o el director (school_admin) del mismo
  // colegio del alumno.
  async getStudentReport(studentId: number, user: UserPayload) {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { schoolId: true },
    });
    if (!student) throw new NotFoundException('Alumno no encontrado');

    if (!isSchoolAdminOf(user, student.schoolId)) {
      // Verificar que el padre tiene acceso a este alumno
      const rel = await this.prisma.userStudent.findFirst({
        where: { userId: user.sub, studentId },
      });
      if (!rel) throw new ForbiddenException('No tienes acceso a las notas de este alumno');
    }

    // Traer todas las notas del alumno con datos de curso y periodo
    const grades = await this.prisma.grade.findMany({
      where: { studentId },
      include: {
        course: { select: { id: true, name: true } },
        period: { select: { id: true, name: true, startDate: true, endDate: true } },
      },
      orderBy: [
        { period: { startDate: 'asc' } },
        { course: { name: 'asc' } },
      ],
    });

    // Agrupar por periodo para facilitar la presentación en la UI
    const byPeriod = grades.reduce<Record<string, typeof grades>>(
      (acc, g) => {
        const key = `${g.periodId}`;
        if (!acc[key]) acc[key] = [];
        acc[key].push(g);
        return acc;
      },
      {},
    );

    return { grades, byPeriod };
  }

  // ── getClassroomGrades ────────────────────────────────────
  // Notas de TODOS los alumnos de un aula en un periodo.
  // Lo usa el profesor para revisar el rendimiento general.
  async getClassroomGrades(classroomId: number, periodId: number, teacherId: bigint) {
    const currentYear = new Date().getFullYear();
    const enrollments = await this.prisma.studentEnrollment.findMany({
      where: { classroomId, academicYear: currentYear, isActive: true },
      include: {
        student: {
          select: { id: true, firstName: true, lastName: true, code: true },
        },
      },
      orderBy: { student: { lastName: 'asc' } },
    });

    // Antes: una query de grade.findMany POR ALUMNO (N+1) dentro de un
    // Promise.all — con connection_limit=5 en el pooler, un aula de más
    // de 5 alumnos ya generaba cola real esperando conexión. Una sola
    // query con `studentId: { in }` trae las notas de todos, se agrupan
    // por alumno en memoria.
    const studentIds = enrollments.map((e) => e.studentId);
    const allGrades =
      studentIds.length > 0
        ? await this.prisma.grade.findMany({
            where: { studentId: { in: studentIds }, periodId },
            include: { course: { select: { name: true } } },
          })
        : [];
    const gradesByStudent = new Map<string, typeof allGrades>();
    for (const g of allGrades) {
      const key = g.studentId.toString();
      const arr = gradesByStudent.get(key);
      if (arr) arr.push(g);
      else gradesByStudent.set(key, [g]);
    }

    const report = enrollments.map((e) => {
      const grades = gradesByStudent.get(e.studentId.toString()) ?? [];
      // Promedio del alumno en este periodo
      const avg =
        grades.length > 0
          ? grades.reduce((sum, g) => sum + Number(g.grade ?? 0), 0) / grades.length
          : null;

      return {
        student: e.student,
        grades,
        average: avg ? Math.round(avg * 10) / 10 : null, // 1 decimal
      };
    });

    return report;
  }
}
