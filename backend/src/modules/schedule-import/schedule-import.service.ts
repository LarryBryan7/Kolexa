// ============================================================
// schedule-import.service.ts — Importar horario de aula desde foto
// ============================================================
// Flujo: foto → Gemini (propone) → este servicio (resuelve y valida) →
// Web Admin / app (el administrador revisa y corrige) → confirm (persiste).
//
// Reglas rectoras:
//   - La IA PROPONE, KOLEXA VALIDA, el ADMINISTRADOR CONFIRMA. `analyze`
//     nunca escribe en la base de datos.
//   - NUNCA se crean cursos ni docentes nuevos porque Gemini los detecte.
//     Si un nombre no coincide con un registro existente del colegio, el
//     bloque se marca para revisión y el admin decide.
//   - Aislamiento multi-tenant: todos los ids (aula, curso, docente) se
//     re-verifican contra el schoolId del JWT en `confirm`, sin confiar en
//     nada que venga del cliente.
// ============================================================

import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { GeminiScheduleService, RawSchedule, SchoolContext } from './gemini-schedule.service';

// dayOfWeek en BD: 1=lunes … 5=viernes
const DAY_TO_NUMBER: Record<string, number> = {
  monday: 1,
  tuesday: 2,
  wednesday: 3,
  thursday: 4,
  friday: 5,
};

const VALID_TYPES = ['class', 'recess', 'break', 'lunch', 'activity'] as const;
type BlockType = (typeof VALID_TYPES)[number];

const HHMM = /^([01]\d|2[0-3]):([0-5]\d)$/;

// Un bloque ya resuelto contra el colegio, listo para que el admin lo revise.
export interface ProposedBlock {
  dayOfWeek: number;
  startTime: string;
  endTime: string;
  type: BlockType;
  // Texto original detectado en la foto (para que el admin vea qué leyó la IA)
  detectedSubject: string | null;
  detectedTeacher: string | null;
  // Resolución contra los registros reales del colegio (null = sin match)
  courseId: string | null;
  courseName: string | null;
  teacherId: string | null;
  teacherName: string | null;
  label: string | null;
  // Motivos por los que este bloque necesita atención del administrador
  issues: string[];
}

export interface AnalyzeResult {
  classroom: { id: string; name: string } | null;
  detectedClassroom: string | null;
  blocks: ProposedBlock[];
  // Resumen para la UI: cuántos bloques requieren revisión y por qué
  summary: {
    total: number;
    needsReview: number;
    unmatchedCourses: string[];
    unmatchedTeachers: string[];
  };
}

// Lo que el admin confirma tras revisar (ya con ids elegidos por él)
export interface ConfirmBlockInput {
  dayOfWeek: number;
  startTime: string;
  endTime: string;
  type: BlockType;
  courseId?: string | null;
  teacherId?: string | null;
  label?: string | null;
}

@Injectable()
export class ScheduleImportService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gemini: GeminiScheduleService,
  ) {}

  // Normaliza para comparar nombres: minúsculas, sin tildes, sin espacios
  // ni signos extra. "MAT." y "mat" caen en la misma clave.
  private normalize(s: string | null | undefined): string {
    if (!s) return '';
    return s
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '')
      .trim();
  }

  // Normalización específica de aulas: además de lo anterior, unifica el grado
  // escrito en palabra con el escrito en número. El cuadro de horarios suele
  // decir "PRIMERO B" mientras el aula en KOLEXA se llama "1ro B", y sin esto
  // el administrador tendría que elegir el aula a mano en cada importación.
  private normalizeClassroom(s: string | null | undefined): string {
    if (!s) return '';
    return s
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .toLowerCase()
      .replace(/\b(primero|primer)\b/g, '1')
      .replace(/\b(segundo)\b/g, '2')
      .replace(/\b(tercero|tercer)\b/g, '3')
      .replace(/\b(cuarto)\b/g, '4')
      .replace(/\b(quinto)\b/g, '5')
      .replace(/\b(sexto)\b/g, '6')
      // Sufijos ordinales: "1ro" / "1er" / "1°" → "1"
      .replace(/(ro|do|to|mo|vo|er)\b/g, '')
      .replace(/[^a-z0-9]/g, '')
      .trim();
  }

  // ─────────────────────────────────────────────────────────
  // FASE ANALYZE — no escribe nada en la base de datos
  // ─────────────────────────────────────────────────────────
  async analyze(
    schoolId: bigint,
    imageBase64: string,
    mimeType: string,
    classroomIdHint?: bigint,
  ): Promise<AnalyzeResult> {
    // Contexto del colegio para desambiguar abreviaturas (Fase 3).
    // Todo se lee filtrado por schoolId: nunca cruzamos colegios.
    const [classrooms, courses, teachers] = await Promise.all([
      this.prisma.classroom.findMany({
        where: { schoolLocation: { schoolId }, isActive: true },
        select: { id: true, name: true, grade: true, section: true },
      }),
      this.prisma.course.findMany({
        where: { schoolId },
        select: { id: true, name: true, code: true },
      }),
      this.prisma.user.findMany({
        where: {
          deletedAt: null,
          userRoles: { some: { schoolId, role: { name: 'teacher' } } },
        },
        select: { id: true, firstName: true, lastName: true },
      }),
    ]);

    const context: SchoolContext = {
      classrooms: classrooms.map((c) => c.name),
      courses: courses.map((c) => c.name),
      teachers: teachers.map((t) => `${t.firstName} ${t.lastName ?? ''}`.trim()),
    };

    const raw = await this.gemini.readSchedule(imageBase64, mimeType, context);

    return this.resolveAndValidate(raw, { classrooms, courses, teachers }, classroomIdHint);
  }

  // Cruza lo detectado por la IA con los registros reales del colegio y
  // marca cada bloque con sus problemas. Separado de `analyze` para poder
  // testearlo sin llamar a Gemini.
  resolveAndValidate(
    raw: RawSchedule,
    school: {
      classrooms: { id: bigint; name: string; grade: string | null; section: string | null }[];
      courses: { id: bigint; name: string; code: string | null }[];
      teachers: { id: bigint; firstName: string; lastName: string | null }[];
    },
    classroomIdHint?: bigint,
  ): AnalyzeResult {
    // ── Aula ──
    // Si el admin ya eligió el aula en la UI, esa manda sobre lo detectado.
    let matchedClassroom = classroomIdHint
      ? school.classrooms.find((c) => c.id === classroomIdHint) ?? null
      : null;

    if (!matchedClassroom && raw.classroom) {
      const target = this.normalizeClassroom(raw.classroom);
      matchedClassroom =
        school.classrooms.find(
          (c) => this.normalizeClassroom(c.name) === target,
        ) ??
        school.classrooms.find(
          (c) =>
            this.normalizeClassroom(`${c.grade ?? ''}${c.section ?? ''}`) ===
            target,
        ) ??
        null;
    }

    // Índices de búsqueda por nombre normalizado (y por código, si tiene)
    const courseByName = new Map<string, (typeof school.courses)[number]>();
    for (const c of school.courses) {
      courseByName.set(this.normalize(c.name), c);
      if (c.code) courseByName.set(this.normalize(c.code), c);
    }
    const teacherByName = new Map<string, (typeof school.teachers)[number]>();
    for (const t of school.teachers) {
      const full = `${t.firstName} ${t.lastName ?? ''}`.trim();
      teacherByName.set(this.normalize(full), t);
    }

    const blocks: ProposedBlock[] = [];
    const unmatchedCourses = new Set<string>();
    const unmatchedTeachers = new Set<string>();

    for (const day of raw.days ?? []) {
      const dayOfWeek = DAY_TO_NUMBER[day.day];
      // Un día inválido no tiene arreglo posible desde la UI (no hay a qué
      // columna asignarlo), así que se descarta en vez de proponerlo roto.
      if (!dayOfWeek) continue;

      for (const p of day.periods ?? []) {
        const issues: string[] = [];

        const type: BlockType = VALID_TYPES.includes(p.type as BlockType)
          ? (p.type as BlockType)
          : 'class';

        const startTime = (p.start ?? '').trim();
        const endTime = (p.end ?? '').trim();
        if (!HHMM.test(startTime) || !HHMM.test(endTime)) {
          issues.push('Horario ilegible: revisa la hora de inicio y fin.');
        } else if (startTime >= endTime) {
          issues.push('La hora de inicio debe ser anterior a la de fin.');
        }

        // Resolución curso/docente SOLO para bloques académicos: un recreo
        // no necesita curso, y exigírselo generaría ruido en la revisión.
        let courseId: bigint | null = null;
        let courseName: string | null = null;
        let teacherId: bigint | null = null;
        let teacherName: string | null = null;
        let label: string | null = null;

        if (type === 'class') {
          if (p.subject) {
            const match = courseByName.get(this.normalize(p.subject));
            if (match) {
              courseId = match.id;
              courseName = match.name;
            } else {
              unmatchedCourses.add(p.subject);
              issues.push(`No existe un curso llamado "${p.subject}" en el colegio.`);
            }
          } else {
            issues.push('Falta el curso de este bloque.');
          }

          if (p.teacher) {
            const match = teacherByName.get(this.normalize(p.teacher));
            if (match) {
              teacherId = match.id;
              teacherName = `${match.firstName} ${match.lastName ?? ''}`.trim();
            } else {
              unmatchedTeachers.add(p.teacher);
              issues.push(`No existe un docente que coincida con "${p.teacher}".`);
            }
          }
          // Sin docente NO es un error: muchos horarios no lo indican y el
          // bloque es válido igual (ClassroomCourse.teacherId es opcional).
        } else {
          // Bloques no académicos: el nombre detectado es su etiqueta.
          label = p.subject?.trim() || null;
          // Sin etiqueta el bloque aparecería en blanco en la app. Pasa cuando
          // la foto trae una celda combinada que cruza varios días con el texto
          // escrito una sola vez: se detecta el bloque en todos, pero el nombre
          // solo en uno. Hay que avisar para que el admin lo nombre o lo borre.
          if (!label) {
            issues.push(
              'Bloque sin nombre: escríbele una etiqueta o elimínalo.',
            );
          }
        }

        blocks.push({
          dayOfWeek,
          startTime,
          endTime,
          type,
          detectedSubject: p.subject ?? null,
          detectedTeacher: p.teacher ?? null,
          courseId: courseId?.toString() ?? null,
          courseName,
          teacherId: teacherId?.toString() ?? null,
          teacherName,
          label,
          issues,
        });
      }
    }

    // Solapamientos: dos bloques del mismo día que se pisan. Se marca en
    // AMBOS para que el admin vea el conflicto desde cualquiera de los dos.
    this.markOverlaps(blocks);

    // Si no se resolvió el aula no es error fatal: `classroom: null` le
    // indica a la UI que el administrador debe elegirla antes de confirmar.
    return {
      classroom: matchedClassroom
        ? { id: matchedClassroom.id.toString(), name: matchedClassroom.name }
        : null,
      detectedClassroom: raw.classroom ?? null,
      blocks,
      summary: {
        total: blocks.length,
        needsReview: blocks.filter((b) => b.issues.length > 0).length,
        unmatchedCourses: [...unmatchedCourses],
        unmatchedTeachers: [...unmatchedTeachers],
      },
    };
  }

  // Marca solapamientos dentro del mismo día. Compara solo bloques con
  // horas válidas (los ilegibles ya traen su propio issue).
  private markOverlaps(blocks: { dayOfWeek: number; startTime: string; endTime: string; issues: string[] }[]) {
    for (let i = 0; i < blocks.length; i++) {
      for (let j = i + 1; j < blocks.length; j++) {
        const a = blocks[i];
        const b = blocks[j];
        if (a.dayOfWeek !== b.dayOfWeek) continue;
        if (!HHMM.test(a.startTime) || !HHMM.test(a.endTime)) continue;
        if (!HHMM.test(b.startTime) || !HHMM.test(b.endTime)) continue;
        // Se solapan si cada uno empieza antes de que el otro termine.
        if (a.startTime < b.endTime && b.startTime < a.endTime) {
          const msg = 'Este bloque se cruza con otro del mismo día.';
          if (!a.issues.includes(msg)) a.issues.push(msg);
          if (!b.issues.includes(msg)) b.issues.push(msg);
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // FASE CONFIRM — única que escribe. Re-valida TODO desde cero.
  // ─────────────────────────────────────────────────────────
  async confirm(schoolId: bigint, classroomId: bigint, blocks: ConfirmBlockInput[]) {
    if (!blocks?.length) {
      throw new BadRequestException('No hay bloques para guardar.');
    }

    // 1. El aula debe pertenecer al colegio del JWT (aislamiento tenant).
    //    Classroom no tiene schoolId directo: cuelga de SchoolLocation.
    const classroom = await this.prisma.classroom.findFirst({
      where: { id: classroomId, schoolLocation: { schoolId } },
      select: { id: true },
    });
    if (!classroom) {
      throw new NotFoundException('Aula no encontrada en este colegio.');
    }

    // 2. Validación estructural de cada bloque (no confiamos en el cliente,
    //    aunque `analyze` ya haya validado: el body pudo editarse a mano).
    const seen: { dayOfWeek: number; startTime: string; endTime: string }[] = [];
    for (const [i, b] of blocks.entries()) {
      const pos = `Bloque ${i + 1}`;

      if (!Number.isInteger(b.dayOfWeek) || b.dayOfWeek < 1 || b.dayOfWeek > 5) {
        throw new BadRequestException(`${pos}: día inválido (debe ser de lunes a viernes).`);
      }
      if (!HHMM.test(b.startTime) || !HHMM.test(b.endTime)) {
        throw new BadRequestException(`${pos}: las horas deben tener formato HH:mm.`);
      }
      if (b.startTime >= b.endTime) {
        throw new BadRequestException(`${pos}: la hora de inicio debe ser anterior a la de fin.`);
      }
      if (!VALID_TYPES.includes(b.type)) {
        throw new BadRequestException(`${pos}: tipo de bloque inválido.`);
      }
      if (b.type === 'class' && !b.courseId) {
        throw new BadRequestException(`${pos}: un bloque de clase necesita un curso.`);
      }

      for (const prev of seen) {
        if (
          prev.dayOfWeek === b.dayOfWeek &&
          b.startTime < prev.endTime &&
          prev.startTime < b.endTime
        ) {
          throw new BadRequestException(`${pos}: se cruza con otro bloque del mismo día.`);
        }
      }
      seen.push({ dayOfWeek: b.dayOfWeek, startTime: b.startTime, endTime: b.endTime });
    }

    // 3. Cursos y docentes referenciados deben ser DEL MISMO colegio.
    //    Sin esto, un admin podría inyectar ids de otro colegio en el body.
    const courseIds = [...new Set(blocks.map((b) => b.courseId).filter(Boolean))] as string[];
    const teacherIds = [...new Set(blocks.map((b) => b.teacherId).filter(Boolean))] as string[];

    if (courseIds.length > 0) {
      const found = await this.prisma.course.findMany({
        where: { id: { in: courseIds.map(BigInt) }, schoolId },
        select: { id: true },
      });
      if (found.length !== courseIds.length) {
        throw new BadRequestException('Hay cursos que no pertenecen a este colegio.');
      }
    }

    if (teacherIds.length > 0) {
      const found = await this.prisma.user.findMany({
        where: {
          id: { in: teacherIds.map(BigInt) },
          deletedAt: null,
          userRoles: { some: { schoolId } },
        },
        select: { id: true },
      });
      if (found.length !== teacherIds.length) {
        throw new BadRequestException('Hay docentes que no pertenecen a este colegio.');
      }
    }

    // 4. Asegurar el vínculo aula↔curso↔docente (ClassroomCourse).
    //    Esto NO crea cursos ni docentes nuevos: solo relaciona registros
    //    existentes que el administrador ya confirmó.
    const classroomCourseByCourse = new Map<string, bigint>();
    for (const courseId of courseIds) {
      const teacherForCourse =
        blocks.find((b) => b.courseId === courseId && b.teacherId)?.teacherId ?? null;

      const link = await this.prisma.classroomCourse.upsert({
        where: {
          classroomId_courseId: { classroomId, courseId: BigInt(courseId) },
        },
        create: {
          classroomId,
          courseId: BigInt(courseId),
          teacherId: teacherForCourse ? BigInt(teacherForCourse) : null,
        },
        // Solo completa el docente si faltaba; nunca pisa una asignación
        // existente hecha desde la administración del colegio.
        update: teacherForCourse ? { teacher: { connect: { id: BigInt(teacherForCourse) } } } : {},
        select: { id: true },
      });
      classroomCourseByCourse.set(courseId, link.id);
    }

    // 5. Reemplazo atómico del horario del aula (mismo criterio que el
    //    horario del docente: se sustituye completo, no se mezcla).
    await this.prisma.$transaction([
      this.prisma.scheduleBlock.deleteMany({ where: { classroomId } }),
      this.prisma.scheduleBlock.createMany({
        data: blocks.map((b) => ({
          classroomId,
          classroomCourseId: b.courseId ? classroomCourseByCourse.get(b.courseId)! : null,
          type: b.type,
          label: b.type === 'class' ? null : b.label?.trim() || null,
          dayOfWeek: b.dayOfWeek,
          startTime: new Date(`1970-01-01T${b.startTime}:00Z`),
          endTime: new Date(`1970-01-01T${b.endTime}:00Z`),
        })),
      }),
    ]);

    return { saved: blocks.length, classroomId: classroomId.toString() };
  }
}
