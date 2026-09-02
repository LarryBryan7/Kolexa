// ============================================================
// homework.service.ts — Lógica de negocio de Tareas
// ============================================================
// Gestiona la creación, edición y seguimiento de tareas escolares.
//
// Rutas que sirve:
//   createHomework()          → POST /homework
//   getClassroomHomework()    → GET /homework/classroom/:id
//   getStudentHomework()      → GET /homework/student/:id (para el padre)
//   updateHomework()          → PATCH /homework/:id
//   updateStudentSubmission() → PATCH /homework/:id/students/:studentId
//   deleteHomework()          → DELETE /homework/:id
// ============================================================

import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateHomeworkDto,
  UpdateHomeworkDto,
  UpdateStudentHomeworkDto,
} from './dto/homework.dto';
import { UserPayload } from '../../common/decorators/current-user.decorator';
import { isSchoolAdminOf } from '../../common/utils/school-staff-access';

@Injectable()
export class HomeworkService {
  constructor(private readonly prisma: PrismaService) {}

  // ── createHomework ────────────────────────────────────────
  // El profesor crea una tarea para su aula.
  // Automáticamente crea un registro StudentHomework vacío
  // para cada alumno matriculado en el aula.
  async createHomework(dto: CreateHomeworkDto, teacherId: bigint) {
    // Ninguna depende del resultado de la otra — corren en paralelo.
    const currentYear = new Date().getFullYear();
    const [classroom, enrollments] = await Promise.all([
      // Verificar que el aula existe
      this.prisma.classroom.findUnique({
        where: { id: dto.classroomId },
      }),
      // Obtener alumnos matriculados en el aula (año actual)
      this.prisma.studentEnrollment.findMany({
        where: {
          classroomId: dto.classroomId,
          academicYear: currentYear,
          isActive: true,
        },
      }),
    ]);
    if (!classroom) {
      throw new NotFoundException(`Aula ${dto.classroomId} no encontrada`);
    }

    // Crear la tarea + los registros de entrega en una transacción
    const homework = await this.prisma.$transaction(async (tx) => {
      // 1. Crear la tarea
      const newHomework = await tx.homework.create({
        data: {
          classroomId: dto.classroomId,
          courseId: dto.courseId,
          teacherId,
          title: dto.title,
          description: dto.description,
          dueDate: new Date(dto.dueDate),
          notifyParents: dto.notifyParents ?? true,
        },
      });

      // 2. Crear un registro de entrega por alumno (estado: pendiente)
      if (enrollments.length > 0) {
        await tx.studentHomework.createMany({
          data: enrollments.map((e) => ({
            homeworkId: newHomework.id,
            studentId: e.studentId,
            status: 'pending',
          })),
        });
      }

      return newHomework;
    });

    // Retornar con todos los datos relacionados
    return this.getHomeworkById(homework.id);
  }

  // ── getHomeworkById ───────────────────────────────────────
  // Obtiene una tarea con todas sus entregas de alumnos.
  async getHomeworkById(homeworkId: bigint) {
    const homework = await this.prisma.homework.findUnique({
      where: { id: homeworkId, deletedAt: null }, // excluir borrados
      include: {
        course: { select: { name: true } },
        teacher: { select: { firstName: true, lastName: true } },
        submissions: {
          include: {
            student: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                code: true,
              },
            },
          },
          orderBy: { student: { lastName: 'asc' } },
        },
        _count: { select: { attachments: true } }, // cuántos adjuntos tiene
      },
    });

    if (!homework) {
      throw new NotFoundException(`Tarea ${homeworkId} no encontrada`);
    }

    return homework;
  }

  // ── getClassroomHomework ──────────────────────────────────
  // Lista de tareas de un aula. El profesor ve solo las suyas; el director
  // (school_admin) del mismo colegio del aula ve TODAS las del aula, sin
  // filtrar por profesor — antes esto devolvía lista vacía para el
  // director en vez de mostrarle las tareas reales.
  // Ordenadas por fecha de entrega (más próxima primero).
  async getClassroomHomework(classroomId: number, user: UserPayload) {
    let isAdmin = false;
    if (user.roles.includes('school_admin')) {
      // Classroom no tiene schoolId directo — pasa por SchoolLocation
      // (el campus físico del aula).
      const classroom = await this.prisma.classroom.findUnique({
        where: { id: classroomId },
        select: { schoolLocation: { select: { schoolId: true } } },
      });
      isAdmin = !!classroom && isSchoolAdminOf(user, classroom.schoolLocation.schoolId);
    }

    return this.prisma.homework.findMany({
      where: {
        classroomId,
        ...(isAdmin ? {} : { teacherId: user.sub }),
        deletedAt: null,
      },
      include: {
        course: { select: { name: true } },
        // Contar cuántos alumnos entregaron vs. total
        _count: { select: { submissions: true } },
      },
      orderBy: { dueDate: 'asc' }, // más próximas primero
    });
  }

  // ── getStudentHomework ────────────────────────────────────
  // Tareas de un alumno específico. Lo ve el padre de familia, o el
  // director (school_admin) del mismo colegio del alumno.
  // Muestra todas las tareas pendientes y recientes.
  async getStudentHomework(studentId: number, user: UserPayload) {
    // Las 3 consultas son independientes (ninguna necesita el RESULTADO
    // de otra) — antes se esperaban en 3 etapas secuenciales. El chequeo
    // de acceso se aplica sobre los resultados ya resueltos.
    const [student, relationship, homework] = await Promise.all([
      this.prisma.student.findUnique({ where: { id: studentId }, select: { schoolId: true } }),
      this.prisma.userStudent.findFirst({ where: { userId: user.sub, studentId } }),
      this.prisma.studentHomework.findMany({
        where: { studentId },
        include: {
          homework: {
            include: {
              course: { select: { name: true } },
              classroom: { select: { name: true, grade: true, section: true } },
              teacher: { select: { firstName: true, lastName: true } },
            },
          },
        },
        orderBy: { homework: { dueDate: 'asc' } },
      }),
    ]);
    if (!student) throw new NotFoundException('Alumno no encontrado');
    if (!isSchoolAdminOf(user, student.schoolId) && !relationship) {
      throw new ForbiddenException('No tienes acceso a las tareas de este alumno');
    }
    return homework;
  }

  // ── updateHomework ────────────────────────────────────────
  // El profesor edita una tarea existente.
  async updateHomework(
    homeworkId: bigint,
    dto: UpdateHomeworkDto,
    teacherId: bigint,
  ) {
    // Verificar que existe y pertenece a este profesor
    const homework = await this.prisma.homework.findUnique({
      where: { id: homeworkId, deletedAt: null },
    });
    if (!homework) throw new NotFoundException('Tarea no encontrada');
    if (homework.teacherId !== teacherId) {
      throw new ForbiddenException('Solo el profesor que creó la tarea puede editarla');
    }

    return this.prisma.homework.update({
      where: { id: homeworkId },
      data: {
        ...(dto.title && { title: dto.title }),
        ...(dto.description && { description: dto.description }),
        ...(dto.dueDate && { dueDate: new Date(dto.dueDate) }),
        ...(dto.notifyParents !== undefined && { notifyParents: dto.notifyParents }),
      },
    });
  }

  // ── updateStudentSubmission ───────────────────────────────
  // El profesor marca la entrega de un alumno como revisada.
  async updateStudentSubmission(
    homeworkId: bigint,
    studentId: number,
    dto: UpdateStudentHomeworkDto,
    teacherId: bigint,
  ) {
    // Verificar que la tarea pertenece a este profesor
    const homework = await this.prisma.homework.findUnique({
      where: { id: homeworkId, deletedAt: null },
    });
    if (!homework) throw new NotFoundException('Tarea no encontrada');
    if (homework.teacherId !== teacherId) {
      throw new ForbiddenException('No tienes permiso para modificar esta entrega');
    }

    return this.prisma.studentHomework.update({
      where: {
        homeworkId_studentId: { homeworkId, studentId },
      },
      data: {
        status: dto.status,
        teacherNote: dto.teacherNote,
        grade: dto.grade,
        // Si el estado es 'reviewed', registrar cuándo se revisó
        reviewedAt: dto.status === 'reviewed' ? new Date() : undefined,
      },
    });
  }

  // ── deleteHomework ────────────────────────────────────────
  // Soft delete: no elimina de la DB, solo marca deletedAt.
  // Esto permite recuperar tareas borradas por error si es necesario.
  async deleteHomework(homeworkId: bigint, teacherId: bigint) {
    const homework = await this.prisma.homework.findUnique({
      where: { id: homeworkId, deletedAt: null },
    });
    if (!homework) throw new NotFoundException('Tarea no encontrada');
    if (homework.teacherId !== teacherId) {
      throw new ForbiddenException('Solo el profesor que creó la tarea puede eliminarla');
    }

    return this.prisma.homework.update({
      where: { id: homeworkId },
      data: { deletedAt: new Date() }, // soft delete
    });
  }
}
