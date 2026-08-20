// ============================================================
// admin.service.ts — Lógica de negocio de la Web Admin
// ============================================================
// Todos los métodos reciben el schoolId del usuario autenticado
// (NUNCA del body/query del cliente) y limitan cada consulta a
// ese colegio para garantizar el aislamiento multi-tenant.
//
// Si un admin intenta acceder a un recurso de otro colegio, se
// devuelve 404 (no se filtra información de la existencia).
// ============================================================

import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateSchoolDto } from './dto/update-school.dto';
import { CreateClassroomDto } from './dto/create-classroom.dto';
import { UpdateClassroomDto } from './dto/update-classroom.dto';
import { CreateCourseDto } from './dto/create-course.dto';
import { UpdateCourseDto } from './dto/update-course.dto';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { CreateStudentDto } from './dto/create-student.dto';
import { UpdateStudentDto } from './dto/update-student.dto';
import { CreateEnrollmentDto } from './dto/create-enrollment.dto';
import { CreateParentLinkDto } from './dto/create-parent-link.dto';
import { CreateParentDto } from './dto/create-parent.dto';
import { UpdateParentDto } from './dto/update-parent.dto';
import { CreateParentStudentLinkDto } from './dto/create-parent-student-link.dto';
import { CreateAssignmentDto } from './dto/create-assignment.dto';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  // ─────────────────────────────────────────────────────────
  // INSTITUCIÓN
  // ─────────────────────────────────────────────────────────

  async getSchool(schoolId: bigint) {
    const school = await this.prisma.school.findUnique({
      where: { id: schoolId },
      select: {
        id: true,
        name: true,
        tradeName: true,
        ruc: true,
        phone: true,
        email: true,
        logoUrl: true,
        address: true,
        isActive: true,
      },
    });
    if (!school) throw new NotFoundException('Colegio no encontrado');
    return school;
  }

  async updateSchool(schoolId: bigint, dto: UpdateSchoolDto) {
    // Verificar que el colegio exista (404 si no)
    await this.getSchool(schoolId);
    return this.prisma.school.update({
      where: { id: schoolId },
      data: dto,
      select: {
        id: true,
        name: true,
        tradeName: true,
        ruc: true,
        phone: true,
        email: true,
        logoUrl: true,
        address: true,
        isActive: true,
      },
    });
  }

  // ─────────────────────────────────────────────────────────
  // AULAS (pertenecen al colegio vía SchoolLocation.schoolId)
  // ─────────────────────────────────────────────────────────

  async listClassrooms(schoolId: bigint) {
    return this.prisma.classroom.findMany({
      where: {
        schoolLocation: { schoolId },
        isActive: true,
      },
      include: {
        schoolLocation: { select: { id: true, name: true } },
        _count: { select: { enrollments: true } },
      },
      orderBy: [{ academicYear: 'desc' }, { grade: 'asc' }, { section: 'asc' }],
    });
  }

  async createClassroom(schoolId: bigint, dto: CreateClassroomDto) {
    // Validar que la sede pertenezca al colegio del admin
    const location = await this.prisma.schoolLocation.findFirst({
      where: { id: BigInt(dto.schoolLocationId), schoolId },
      select: { id: true },
    });
    if (!location) throw new NotFoundException('Sede no encontrada');

    return this.prisma.classroom.create({
      data: {
        schoolLocationId: location.id,
        name: dto.name,
        grade: dto.grade,
        section: dto.section,
        academicYear: dto.academicYear,
      },
    });
  }

  private async getClassroomOwned(schoolId: bigint, id: bigint) {
    const classroom = await this.prisma.classroom.findFirst({
      where: { id, schoolLocation: { schoolId } },
    });
    if (!classroom) throw new NotFoundException('Aula no encontrada');
    return classroom;
  }

  async updateClassroom(schoolId: bigint, id: bigint, dto: UpdateClassroomDto) {
    await this.getClassroomOwned(schoolId, id);
    return this.prisma.classroom.update({
      where: { id },
      data: dto,
    });
  }

  async deleteClassroom(schoolId: bigint, id: bigint) {
    await this.getClassroomOwned(schoolId, id);
    // Soft-delete: marcar como inactivo en lugar de borrar físicamente,
    // para no romper referencias históricas (matrículas, horarios, etc.)
    return this.prisma.classroom.update({
      where: { id },
      data: { isActive: false },
    });
  }

  // ─────────────────────────────────────────────────────────
  // CURSOS (tienen schoolId directo)
  // ─────────────────────────────────────────────────────────

  async listCourses(schoolId: bigint) {
    return this.prisma.course.findMany({
      where: { schoolId },
      include: {
        _count: { select: { classroomCourses: true } },
      },
      orderBy: { name: 'asc' },
    });
  }

  async createCourse(schoolId: bigint, dto: CreateCourseDto) {
    return this.prisma.course.create({
      data: {
        schoolId,
        name: dto.name,
        code: dto.code,
      },
    });
  }

  private async getCourseOwned(schoolId: bigint, id: bigint) {
    const course = await this.prisma.course.findFirst({
      where: { id, schoolId },
    });
    if (!course) throw new NotFoundException('Curso no encontrado');
    return course;
  }

  async updateCourse(schoolId: bigint, id: bigint, dto: UpdateCourseDto) {
    await this.getCourseOwned(schoolId, id);
    return this.prisma.course.update({
      where: { id },
      data: dto,
    });
  }

  async deleteCourse(schoolId: bigint, id: bigint) {
    await this.getCourseOwned(schoolId, id);
    // Verificar que no tenga asignaciones antes de borrar
    const count = await this.prisma.classroomCourse.count({
      where: { courseId: id },
    });
    if (count > 0) {
      throw new ConflictException(
        'No se puede eliminar el curso porque tiene aulas asignadas',
      );
    }
    return this.prisma.course.delete({ where: { id } });
  }

  // ─────────────────────────────────────────────────────────
  // USUARIOS (pertenencia vía UserRole.schoolId)
  // ─────────────────────────────────────────────────────────

  async listUsers(schoolId: bigint, search?: string) {
    const term = search?.trim();
    return this.prisma.user.findMany({
      where: {
        deletedAt: null,
        userRoles: { some: { schoolId } },
        ...(term
          ? {
              OR: [
                { firstName: { contains: term, mode: 'insensitive' } },
                { lastName: { contains: term, mode: 'insensitive' } },
                { email: { contains: term, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      include: {
        userRoles: {
          where: { schoolId },
          include: { role: { select: { name: true } } },
        },
      },
      orderBy: { firstName: 'asc' },
    });
  }

  async createUser(schoolId: bigint, dto: CreateUserDto) {
    // Buscar el rol por nombre ('teacher' | 'parent')
    const role = await this.prisma.role.findUnique({
      where: { name: dto.role },
      select: { id: true },
    });
    if (!role) throw new BadRequestException('Rol no encontrado');

    // Si el email ya existe (usuario global), reutilizamos el usuario y solo
    // añadimos el UserRole para este colegio. Si no existe, lo creamos.
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
      select: { id: true },
    });

    if (existing) {
      // Verificar que no tenga ya este rol en este colegio
      const dup = await this.prisma.userRole.findFirst({
        where: { userId: existing.id, roleId: role.id, schoolId },
        select: { id: true },
      });
      if (dup) {
        throw new ConflictException(
          'El usuario ya tiene este rol en el colegio',
        );
      }
      await this.prisma.userRole.create({
        data: { userId: existing.id, roleId: role.id, schoolId },
      });
      return this.prisma.user.findUnique({
        where: { id: existing.id },
        include: {
          userRoles: {
            where: { schoolId },
            include: { role: { select: { name: true } } },
          },
        },
      });
    }

    // Crear usuario sin contraseña (needsPasswordChange=true).
    // El usuario define su contraseña mediante el flujo de activación/invitación.
    return this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash: '', // sin contraseña; se define en la activación
        firstName: dto.firstName,
        lastName: dto.lastName,
        dni: dto.dni,
        phone: dto.phone,
        needsPasswordChange: true,
        userRoles: {
          create: { roleId: role.id, schoolId },
        },
      },
      include: {
        userRoles: {
          where: { schoolId },
          include: { role: { select: { name: true } } },
        },
      },
    });
  }

  private async getUserOwned(schoolId: bigint, id: bigint) {
    const user = await this.prisma.user.findFirst({
      where: {
        id,
        deletedAt: null,
        userRoles: { some: { schoolId } },
      },
    });
    if (!user) throw new NotFoundException('Usuario no encontrado');
    return user;
  }

  async updateUser(schoolId: bigint, id: bigint, dto: UpdateUserDto) {
    await this.getUserOwned(schoolId, id);
    return this.prisma.user.update({
      where: { id },
      data: dto,
      include: {
        userRoles: {
          where: { schoolId },
          include: { role: { select: { name: true } } },
        },
      },
    });
  }

  // ─────────────────────────────────────────────────────────
  // ALUMNOS (tienen schoolId directo)
  // ─────────────────────────────────────────────────────────

  async listStudents(schoolId: bigint, search?: string) {
    const term = search?.trim();
    return this.prisma.student.findMany({
      where: {
        schoolId,
        deletedAt: null,
        ...(term
          ? {
              OR: [
                { firstName: { contains: term, mode: 'insensitive' } },
                { lastName: { contains: term, mode: 'insensitive' } },
                { dni: { contains: term, mode: 'insensitive' } },
                { code: { contains: term, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      include: {
        enrollments: {
          where: { isActive: true },
          include: { classroom: { select: { grade: true, section: true, academicYear: true } } },
        },
        _count: { select: { parentLinks: true } },
      },
      orderBy: { firstName: 'asc' },
    });
  }

  async createStudent(schoolId: bigint, dto: CreateStudentDto) {
    // Se exige al menos un identificador fuerte (dni o code)
    if (!dto.dni && !dto.code) {
      throw new BadRequestException(
        'Se requiere al menos un identificador (DNI o código) para el alumno',
      );
    }
    return this.prisma.student.create({
      data: {
        schoolId,
        firstName: dto.firstName,
        lastName: dto.lastName,
        dni: dto.dni,
        code: dto.code,
        birthday: dto.birthday ? new Date(dto.birthday) : undefined,
        sex: dto.sex,
      },
    });
  }

  private async getStudentOwned(schoolId: bigint, id: bigint) {
    const student = await this.prisma.student.findFirst({
      where: { id, schoolId, deletedAt: null },
    });
    if (!student) throw new NotFoundException('Alumno no encontrado');
    return student;
  }

  async updateStudent(schoolId: bigint, id: bigint, dto: UpdateStudentDto) {
    await this.getStudentOwned(schoolId, id);
    return this.prisma.student.update({
      where: { id },
      data: {
        ...dto,
        birthday: dto.birthday ? new Date(dto.birthday) : undefined,
      },
    });
  }

  // ─────────────────────────────────────────────────────────
  // MATRÍCULAS
  // ─────────────────────────────────────────────────────────

  async createEnrollment(schoolId: bigint, dto: CreateEnrollmentDto) {
    // Verificar que el alumno pertenezca al colegio
    await this.getStudentOwned(schoolId, BigInt(dto.studentId));
    // Verificar que el aula pertenezca al colegio
    await this.getClassroomOwned(schoolId, BigInt(dto.classroomId));

    // Evitar matrícula duplicada (constraint @@unique([studentId, classroomId, academicYear]))
    const dup = await this.prisma.studentEnrollment.findFirst({
      where: {
        studentId: BigInt(dto.studentId),
        classroomId: BigInt(dto.classroomId),
        academicYear: dto.academicYear,
      },
      select: { id: true },
    });
    if (dup) {
      throw new ConflictException('El alumno ya está matriculado en este aula para ese año');
    }

    return this.prisma.studentEnrollment.create({
      data: {
        studentId: BigInt(dto.studentId),
        classroomId: BigInt(dto.classroomId),
        academicYear: dto.academicYear,
      },
    });
  }

  async deleteEnrollment(schoolId: bigint, id: bigint) {
    // Verificar que la matrícula pertenezca al colegio (vía student o classroom)
    const enrollment = await this.prisma.studentEnrollment.findFirst({
      where: {
        id,
        OR: [
          { student: { schoolId } },
          { classroom: { schoolLocation: { schoolId } } },
        ],
      },
      select: { id: true },
    });
    if (!enrollment) throw new NotFoundException('Matrícula no encontrada');
    return this.prisma.studentEnrollment.update({
      where: { id },
      data: { isActive: false },
    });
  }

  // ─────────────────────────────────────────────────────────
  // VÍNCULO PADRE ↔ ALUMNO
  // ─────────────────────────────────────────────────────────

  async createParentLink(schoolId: bigint, dto: CreateParentLinkDto) {
    // Verificar que el alumno pertenezca al colegio
    await this.getStudentOwned(schoolId, BigInt(dto.studentId));

    // Verificar que el usuario tenga rol 'parent' en este colegio
    const parent = await this.prisma.userRole.findFirst({
      where: {
        userId: BigInt(dto.userId),
        schoolId,
        role: { name: 'parent' },
      },
      select: { id: true },
    });
    if (!parent) {
      throw new BadRequestException(
        'El usuario no tiene rol de padre en este colegio',
      );
    }

    // Evitar vínculo duplicado (constraint @@unique([userId, studentId]))
    const dup = await this.prisma.userStudent.findFirst({
      where: {
        userId: BigInt(dto.userId),
        studentId: BigInt(dto.studentId),
      },
      select: { id: true },
    });
    if (dup) {
      throw new ConflictException('El padre ya está vinculado a este alumno');
    }

    return this.prisma.userStudent.create({
      data: {
        userId: BigInt(dto.userId),
        studentId: BigInt(dto.studentId),
        relationship: dto.relationship,
        isPrimary: dto.isPrimary ?? false,
      },
    });
  }

  async deleteParentLink(schoolId: bigint, id: bigint) {
    // Verificar que el vínculo pertenezca al colegio (vía student)
    const link = await this.prisma.userStudent.findFirst({
      where: { id, student: { schoolId } },
      select: { id: true },
    });
    if (!link) throw new NotFoundException('Vínculo no encontrado');
    return this.prisma.userStudent.delete({ where: { id } });
  }

  // ─────────────────────────────────────────────────────────
  // PADRES / APODERADOS (información institucional)
  // ─────────────────────────────────────────────────────────
  // Parent es la entidad INSTITUCIONAL del padre/apoderado, separada de la
  // cuenta de autenticación (User). La Web Admin gestiona esta información
  // SIN crear cuentas ni contraseñas: el padre crea/activa su cuenta desde
  // la app móvil y se vincula vía userId (opcional).
  //
  // Invariante de consistencia userId ↔ linkStatus (garantizada aquí, no por
  // CHECK SQL):
  //   - userId = null  → linkStatus NUNCA 'linked' (solo 'pending' o 'unlinked')
  //   - userId != null → linkStatus DEBE ser 'linked'
  //   - linkStatus = 'unlinked' → userId = null
  private static readonly LINK_STATUSES = ['pending', 'linked', 'unlinked'] as const;

  private assertLinkStatusConsistency(userId: bigint | null, linkStatus: string) {
    if (!AdminService.LINK_STATUSES.includes(linkStatus as any)) {
      throw new BadRequestException(
        `linkStatus inválido. Valores permitidos: ${AdminService.LINK_STATUSES.join(', ')}`,
      );
    }
    if (userId === null && linkStatus === 'linked') {
      throw new BadRequestException(
        'Un Parent sin cuenta vinculada (userId = null) no puede tener linkStatus = linked',
      );
    }
    if (userId !== null && linkStatus !== 'linked') {
      throw new BadRequestException(
        'Un Parent con cuenta vinculada (userId != null) debe tener linkStatus = linked',
      );
    }
    if (linkStatus === 'unlinked' && userId !== null) {
      throw new BadRequestException(
        'Un Parent con linkStatus = unlinked debe tener userId = null',
      );
    }
  }

  async listParents(schoolId: bigint, search?: string) {
    const term = search?.trim();
    return this.prisma.parent.findMany({
      where: {
        schoolId,
        ...(term
          ? {
              OR: [
                { firstName: { contains: term, mode: 'insensitive' } },
                { lastName: { contains: term, mode: 'insensitive' } },
                { dni: { contains: term, mode: 'insensitive' } },
                { email: { contains: term, mode: 'insensitive' } },
              ],
            }
          : {}),
      },
      include: {
        user: { select: { id: true, email: true, isActive: true } },
        students: {
          include: {
            student: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                code: true,
                dni: true,
              },
            },
          },
        },
      },
      orderBy: { firstName: 'asc' },
    });
  }

  async createParent(schoolId: bigint, dto: CreateParentDto) {
    // Se exige al menos un identificador fuerte (dni o email) para poder
    // vincular la cuenta del padre desde la app móvil más adelante.
    if (!dto.dni && !dto.email) {
      throw new BadRequestException(
        'Se requiere al menos un identificador (DNI o email) para el padre',
      );
    }
    // La Web Admin crea el Parent SIN cuenta (userId = null, linkStatus = 'pending').
    // assertLinkStatusConsistency no se llama aquí porque el DTO no expone
    // userId ni linkStatus — la invariante se mantiene por construcción.
    return this.prisma.parent.create({
      data: {
        schoolId,
        firstName: dto.firstName,
        lastName: dto.lastName,
        dni: dto.dni,
        phone: dto.phone,
        email: dto.email,
        // linkStatus queda 'pending' hasta que el padre vincule su cuenta desde la app.
      },
    });
  }

  private async getParentOwned(schoolId: bigint, id: bigint) {
    const parent = await this.prisma.parent.findFirst({
      where: { id, schoolId },
    });
    if (!parent) throw new NotFoundException('Padre no encontrado');
    return parent;
  }

  async updateParent(schoolId: bigint, id: bigint, dto: UpdateParentDto) {
    const parent = await this.getParentOwned(schoolId, id);
    // El DTO de admin no gestiona userId ni linkStatus (eso es de la vinculación
    // futura desde la app), por lo que la invariante se mantiene. Se valida el
    // estado actual por robustez.
    this.assertLinkStatusConsistency(parent.userId, parent.linkStatus);
    return this.prisma.parent.update({
      where: { id },
      data: {
        firstName: dto.firstName,
        lastName: dto.lastName,
        dni: dto.dni,
        phone: dto.phone,
        email: dto.email,
        isActive: dto.isActive,
      },
    });
  }

  // Hallazgo IM-8 de la auditoría: antes se leía parent.userId UNA vez al
  // inicio (vía getParentOwned) y ese valor CAPTURADO se usaba varias
  // consultas después para decidir el bridge — si el padre completaba su
  // vinculación de Google (loginWithGoogle, que sí es atómica) justo en
  // esa ventana, el ParentStudent recién creado quedaba sin su
  // UserStudent puente, huérfano de forma permanente (los logins
  // posteriores del padre son idempotentes y no vuelven a recorrer este
  // bridge). Ahora todo va en una transacción y userId se relee FRESCO
  // (tx.parent.findUnique) justo antes de decidir, nunca desde un valor
  // capturado fuera de la transacción.
  async createParentStudentLink(schoolId: bigint, dto: CreateParentStudentLinkDto) {
    // Verificar que el padre pertenezca al colegio (solo existencia/
    // ownership — el userId de este objeto NO se usa para el bridge).
    await this.getParentOwned(schoolId, BigInt(dto.parentId));
    // Verificar que el alumno pertenezca al colegio
    await this.getStudentOwned(schoolId, BigInt(dto.studentId));

    // Evitar vínculo duplicado (constraint @@unique([parentId, studentId]))
    const dup = await this.prisma.parentStudent.findFirst({
      where: {
        parentId: BigInt(dto.parentId),
        studentId: BigInt(dto.studentId),
      },
      select: { id: true },
    });
    if (dup) {
      throw new ConflictException('El padre ya está vinculado a este alumno');
    }

    return this.prisma.$transaction(async (tx) => {
      const link = await tx.parentStudent.create({
        data: {
          parentId: BigInt(dto.parentId),
          studentId: BigInt(dto.studentId),
          relationship: dto.relationship,
          isPrimary: dto.isPrimary ?? false,
        },
      });

      // Puente ParentStudent → UserStudent: todo el acceso real de la app
      // (asistencia, notas, pagos, notificaciones — ver AuthService y los
      // *.service.ts que consultan userStudent) se resuelve por
      // UserStudent, no por ParentStudent. Lectura fresca dentro de la
      // misma transacción del create — ver nota de IM-8 arriba.
      const freshParent = await tx.parent.findUnique({
        where: { id: BigInt(dto.parentId) },
        select: { userId: true },
      });
      if (freshParent?.userId != null) {
        await tx.userStudent.upsert({
          where: {
            userId_studentId: { userId: freshParent.userId, studentId: BigInt(dto.studentId) },
          },
          create: {
            userId: freshParent.userId,
            studentId: BigInt(dto.studentId),
            relationship: dto.relationship,
            isPrimary: dto.isPrimary ?? false,
          },
          update: {},
        });
      }

      return link;
    });
  }

  async deleteParentStudentLink(schoolId: bigint, id: bigint) {
    // Verificar que el vínculo pertenezca al colegio (vía parent o student)
    const link = await this.prisma.parentStudent.findFirst({
      where: {
        id,
        OR: [
          { parent: { schoolId } },
          { student: { schoolId } },
        ],
      },
      select: { id: true, parentId: true, studentId: true },
    });
    if (!link) throw new NotFoundException('Vínculo no encontrado');

    // Espejo inverso: si este vínculo tenía su UserStudent puente (ver
    // createParentStudentLink), eliminarlo también — de lo contrario el
    // padre conserva acceso a un alumno que el colegio acaba de desvincular.
    // userId se relee FRESCO dentro de la transacción (mismo razonamiento
    // de IM-8 que en createParentStudentLink) en vez de confiar en un
    // valor capturado en el findFirst de arriba.
    return this.prisma.$transaction(async (tx) => {
      const freshParent = await tx.parent.findUnique({
        where: { id: link.parentId },
        select: { userId: true },
      });
      if (freshParent?.userId != null) {
        await tx.userStudent.deleteMany({
          where: { userId: freshParent.userId, studentId: link.studentId },
        });
      }
      return tx.parentStudent.delete({ where: { id } });
    });
  }

  // ─────────────────────────────────────────────────────────
  // ASIGNACIÓN DOCENTE–CURSO–AULA
  // ─────────────────────────────────────────────────────────

  async createAssignment(schoolId: bigint, dto: CreateAssignmentDto) {
    // Verificar que el aula pertenezca al colegio
    await this.getClassroomOwned(schoolId, BigInt(dto.classroomId));
    // Verificar que el curso pertenezca al colegio
    await this.getCourseOwned(schoolId, BigInt(dto.courseId));

    // Si se asigna docente, verificar que tenga rol 'teacher' en este colegio
    if (dto.teacherId) {
      const teacher = await this.prisma.userRole.findFirst({
        where: {
          userId: BigInt(dto.teacherId),
          schoolId,
          role: { name: 'teacher' },
        },
        select: { id: true },
      });
      if (!teacher) {
        throw new BadRequestException(
          'El usuario no tiene rol de docente en este colegio',
        );
      }
    }

    // Evitar asignación duplicada (constraint @@unique([classroomId, courseId]))
    const dup = await this.prisma.classroomCourse.findFirst({
      where: {
        classroomId: BigInt(dto.classroomId),
        courseId: BigInt(dto.courseId),
      },
      select: { id: true },
    });
    if (dup) {
      throw new ConflictException('Este curso ya está asignado a este aula');
    }

    return this.prisma.classroomCourse.create({
      data: {
        classroomId: BigInt(dto.classroomId),
        courseId: BigInt(dto.courseId),
        teacherId: dto.teacherId ? BigInt(dto.teacherId) : undefined,
      },
    });
  }

  async deleteAssignment(schoolId: bigint, id: bigint) {
    // Verificar que la asignación pertenezca al colegio (vía classroom o course)
    const assignment = await this.prisma.classroomCourse.findFirst({
      where: {
        id,
        OR: [
          { classroom: { schoolLocation: { schoolId } } },
          { course: { schoolId } },
        ],
      },
      select: { id: true },
    });
    if (!assignment) throw new NotFoundException('Asignación no encontrada');
    return this.prisma.classroomCourse.delete({ where: { id } });
  }
}
