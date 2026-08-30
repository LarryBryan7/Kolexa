// ============================================================
// classroom-import.service.ts — Importar aulas y cursos desde Google Classroom
// ============================================================
// Mismo contrato que la importación por foto: Classroom PROPONE, KOLEXA VALIDA,
// el administrador CONFIRMA. `analyze` nunca escribe; `confirm` es lo único que
// persiste, y re-valida todo desde cero sin confiar en lo que manda el cliente.
//
// Por qué agrupar por `section`: Google Classroom no tiene entidad "aula". Cada
// docente escribe la sección a mano en un campo de texto libre, así que el mismo
// aula puede llegar como "1ro B", "1B" o "Primero B". Se normaliza para
// agruparlas, pero la decisión final es del administrador.
// ============================================================

import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from "@nestjs/common";
import { PrismaService } from "../../prisma/prisma.service";

export interface ProposedCourse {
  googleCourseId: string;
  googleName: string;
  teacherName: string | null;
  teacherId: string | null;
  studentCount: number;
  // Curso institucional que ya existe con ese nombre, si lo hay.
  matchedCourseId: string | null;
  matchedCourseName: string | null;
  alreadyLinked: boolean;
}

// Alumno del roster de Classroom, ya cruzado contra los alumnos del colegio.
// El emparejamiento automático lo hace el sync del docente por nombre completo
// normalizado; acá solo se reporta el resultado para que el admin resuelva los
// que no calzaron (orden apellido-nombre, iniciales, segundos nombres…).
export interface ProposedStudent {
  googleId: string;
  fullName: string;
  email: string | null;
  // Alumno del colegio con el que ya está enlazado, si el sync lo emparejó.
  matchedStudentId: string | null;
  matchedStudentName: string | null;
  // Candidato por nombre parecido, para proponerlo cuando no hubo match exacto.
  suggestedStudentId: string | null;
  suggestedStudentName: string | null;
}

export interface ProposedClassroom {
  // Sección tal como la escribieron los docentes (la variante más frecuente).
  detectedSection: string;
  // Todas las variantes que se agruparon aquí, para que el admin las vea.
  variants: string[];
  matchedClassroomId: string | null;
  courses: ProposedCourse[];
  // Alumnos únicos del roster de todos los cursos de esta aula.
  students: ProposedStudent[];
}

export interface ClassroomAnalyzeResult {
  classrooms: ProposedClassroom[];
  summary: {
    totalCourses: number;
    withoutSection: number;
    alreadyLinked: number;
    totalStudents: number;
    unmatchedStudents: number;
  };
}

export interface ConfirmClassroomInput {
  // Aula destino: existente (classroomId) o nueva (name).
  classroomId?: string;
  newClassroomName?: string;
  courses: {
    googleCourseId: string;
    // Curso destino: existente (courseId) o nuevo (name).
    courseId?: string;
    newCourseName?: string;
    teacherId?: string | null;
  }[];
  // Resolución de los alumnos del roster. Cada uno: enlazar a un alumno
  // existente (studentId), crear uno nuevo (createWithName) o ignorar.
  students?: {
    googleId: string;
    studentId?: string;
    createWithName?: string;
  }[];
}

@Injectable()
export class ClassroomImportService {
  constructor(private readonly prisma: PrismaService) {}

  // Normalización para agrupar secciones escritas a mano:
  // "1ro B" / "1B" / "Primero B" → "1b". Quita acentos, espacios y ordinales.
  private normalizeSection(raw: string): string {
    return raw
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .replace(/\b(primero|primer)\b/g, "1")
      .replace(/\b(segundo)\b/g, "2")
      .replace(/\b(tercero|tercer)\b/g, "3")
      .replace(/\b(cuarto)\b/g, "4")
      .replace(/\b(quinto)\b/g, "5")
      .replace(/\b(sexto)\b/g, "6")
      .replace(/(ro|do|to|mo|vo|er)\b/g, "")
      .replace(/[^a-z0-9]/g, "");
  }

  private normalizeName(raw: string): string {
    return raw
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .replace(/[^a-z0-9]/g, "");
  }

  // ── ANALYZE: lee Classroom y propone. NUNCA escribe. ─────────
  async analyze(schoolId: bigint): Promise<ClassroomAnalyzeResult> {
    // Cursos de Classroom de los docentes de ESTE colegio (aislamiento por rol).
    const gcCourses = await this.prisma.gcTeacherCourse.findMany({
      where: {
        teacher: {
          userRoles: { some: { schoolId, role: { name: "teacher" } } },
        },
      },
      select: {
        googleId: true,
        name: true,
        section: true,
        studentCount: true,
        teacherId: true,
        teacher: { select: { id: true, firstName: true, lastName: true } },
      },
    });

    const [existingClassrooms, existingCourses, existingLinks] =
      await Promise.all([
        this.prisma.classroom.findMany({
          where: { schoolLocation: { schoolId }, isActive: true },
          select: { id: true, name: true },
        }),
        this.prisma.course.findMany({
          where: { schoolId },
          select: { id: true, name: true },
        }),
        this.prisma.gcCourseLink.findMany({
          where: { schoolId },
          select: { googleCourseId: true },
        }),
      ]);

    const classroomByNorm = new Map(
      existingClassrooms.map((c) => [this.normalizeSection(c.name), c]),
    );
    const courseByNorm = new Map(
      existingCourses.map((c) => [this.normalizeName(c.name), c]),
    );
    const linked = new Set(existingLinks.map((l) => l.googleCourseId));

    // Agrupar por sección normalizada.
    const groups = new Map<
      string,
      { variants: Map<string, number>; courses: ProposedCourse[] }
    >();
    let withoutSection = 0;

    for (const gc of gcCourses) {
      const rawSection = gc.section?.trim();
      if (!rawSection) {
        withoutSection++;
        continue; // sin sección no se puede proponer aula; el admin lo hará a mano
      }

      const key = this.normalizeSection(rawSection);
      if (!groups.has(key))
        groups.set(key, { variants: new Map(), courses: [] });
      const group = groups.get(key)!;
      group.variants.set(rawSection, (group.variants.get(rawSection) ?? 0) + 1);

      const matched = courseByNorm.get(this.normalizeName(gc.name));
      group.courses.push({
        googleCourseId: gc.googleId,
        googleName: gc.name,
        teacherName: gc.teacher
          ? `${gc.teacher.firstName} ${gc.teacher.lastName ?? ""}`.trim()
          : null,
        teacherId: gc.teacherId.toString(),
        studentCount: gc.studentCount,
        matchedCourseId: matched?.id.toString() ?? null,
        matchedCourseName: matched?.name ?? null,
        alreadyLinked: linked.has(gc.googleId),
      });
    }

    // ── Roster: alumnos de Classroom por aula ──────────────────
    // Se cargan todos de una vez y se agrupan en memoria; un alumno aparece en
    // varios cursos del mismo aula y solo debe listarse una vez.
    const rosterRows = await this.prisma.gcCourseStudent.findMany({
      where: { course: { googleId: { in: gcCourses.map((c) => c.googleId) } } },
      select: {
        googleId: true,
        fullName: true,
        email: true,
        studentId: true,
        student: { select: { id: true, firstName: true, lastName: true } },
        course: { select: { googleId: true } },
      },
    });

    // Alumnos del colegio, para sugerir candidatos cuando no hubo match exacto.
    const schoolStudents = await this.prisma.student.findMany({
      where: { schoolId, deletedAt: null },
      select: { id: true, firstName: true, lastName: true },
    });
    // Índice por apellido normalizado: cubre el caso peruano más común, que la
    // lista escolar venga como "Apellido, Nombre" o con el nombre abreviado.
    const byFullName = new Map<string, (typeof schoolStudents)[number]>();
    for (const st of schoolStudents) {
      byFullName.set(
        this.normalizeName(`${st.firstName} ${st.lastName ?? ""}`),
        st,
      );
    }
    const byLastName = new Map<string, (typeof schoolStudents)[number]>();
    for (const s of schoolStudents) {
      const k = this.normalizeName(s.lastName ?? "");
      if (k && !byLastName.has(k)) byLastName.set(k, s);
    }

    // googleCourseId → sección normalizada, para repartir el roster por aula.
    const sectionByCourse = new Map<string, string>();
    for (const gc of gcCourses) {
      const sec = gc.section?.trim();
      if (sec) sectionByCourse.set(gc.googleId, this.normalizeSection(sec));
    }

    const studentsBySection = new Map<string, Map<string, ProposedStudent>>();
    for (const r of rosterRows) {
      const key = sectionByCourse.get(r.course.googleId);
      if (!key) continue;
      if (!studentsBySection.has(key)) studentsBySection.set(key, new Map());
      const bucket = studentsBySection.get(key)!;
      if (bucket.has(r.googleId)) continue; // ya listado desde otro curso

      // Emparejamiento en dos niveles, recalculado en CADA análisis. Es
      // deliberado que no dependa solo de lo que guardó el sync del docente:
      // si el administrador corrige el nombre de un alumno en KOLEXA, quiere
      // que al volver a leer el emparejamiento aparezca, sin tener que pedirle
      // al docente que sincronice otra vez desde la app.
      let matched: (typeof schoolStudents)[number] | null = r.student ?? null;
      let suggested: (typeof schoolStudents)[number] | null = null;

      if (!matched) {
        const norm = this.normalizeName(r.fullName);
        // 1. Nombre completo idéntico → se trata como emparejado.
        matched = byFullName.get(norm) ?? null;

        // 2. Si no, apellido contenido en el nombre → solo se sugiere, porque
        //    dos hermanos comparten apellido y la propuesta puede ser errónea.
        if (!matched) {
          for (const [lastName, cand] of byLastName) {
            if (lastName.length >= 4 && norm.includes(lastName)) {
              suggested = cand;
              break;
            }
          }
        }
      }

      bucket.set(r.googleId, {
        googleId: r.googleId,
        fullName: r.fullName,
        email: r.email,
        matchedStudentId: matched?.id.toString() ?? null,
        matchedStudentName: matched
          ? `${matched.firstName} ${matched.lastName ?? ""}`.trim()
          : null,
        suggestedStudentId: suggested?.id.toString() ?? null,
        suggestedStudentName: suggested
          ? `${suggested.firstName} ${suggested.lastName ?? ""}`.trim()
          : null,
      });
    }

    const classrooms: ProposedClassroom[] = [...groups.entries()].map(
      ([key, g]) => {
        // La variante más escrita gana como nombre propuesto.
        const variants = [...g.variants.entries()].sort((a, b) => b[1] - a[1]);
        return {
          detectedSection: variants[0][0],
          variants: variants.map((v) => v[0]),
          matchedClassroomId: classroomByNorm.get(key)?.id.toString() ?? null,
          courses: g.courses.sort((a, b) =>
            a.googleName.localeCompare(b.googleName),
          ),
          students: [...(studentsBySection.get(key)?.values() ?? [])].sort(
            (a, b) => a.fullName.localeCompare(b.fullName),
          ),
        };
      },
    );

    const allStudents = classrooms.flatMap((c) => c.students);

    return {
      classrooms: classrooms.sort((a, b) =>
        a.detectedSection.localeCompare(b.detectedSection),
      ),
      summary: {
        totalCourses: gcCourses.length,
        withoutSection,
        alreadyLinked: gcCourses.filter((c) => linked.has(c.googleId)).length,
        totalStudents: allStudents.length,
        unmatchedStudents: allStudents.filter((s) => !s.matchedStudentId)
          .length,
      },
    };
  }

  // ── CONFIRM: única escritura. Re-valida todo. ────────────────
  async confirm(schoolId: bigint, groups: ConfirmClassroomInput[]) {
    if (!groups.length)
      throw new BadRequestException("No hay aulas para confirmar");

    // El aula necesita una sede del colegio; se usa la primera activa.
    const location = await this.prisma.schoolLocation.findFirst({
      where: { schoolId, isActive: true },
      select: { id: true },
    });
    if (!location)
      throw new NotFoundException("El colegio no tiene una sede activa");

    const year = new Date().getFullYear();

    // ── Validación previa, FUERA de la transacción ──────────────
    // Se resuelve todo lo que no depende de escrituras en dos consultas, en vez
    // de una por curso: con 9 cursos el N+1 hacía ~45 idas al pooler y la
    // transacción se pasaba del tiempo máximo.
    const teacherIds = [
      ...new Set(
        groups.flatMap((g) =>
          g.courses.map((c) => c.teacherId).filter(Boolean),
        ),
      ),
    ] as string[];
    const courseIds = [
      ...new Set(
        groups.flatMap((g) => g.courses.map((c) => c.courseId).filter(Boolean)),
      ),
    ] as string[];
    const classroomIds = [
      ...new Set(groups.map((g) => g.classroomId).filter(Boolean)),
    ] as string[];
    const studentIds = [
      ...new Set(
        groups.flatMap((g) =>
          (g.students ?? []).map((s) => s.studentId).filter(Boolean),
        ),
      ),
    ] as string[];

    const [
      validTeachers,
      validCourses,
      validClassrooms,
      teacherRole,
      validStudents,
    ] = await Promise.all([
      teacherIds.length
        ? this.prisma.user.findMany({
            where: {
              id: { in: teacherIds.map(BigInt) },
              deletedAt: null,
              userRoles: { some: { schoolId, role: { name: "teacher" } } },
            },
            select: { id: true },
          })
        : [],
      courseIds.length
        ? this.prisma.course.findMany({
            where: { id: { in: courseIds.map(BigInt) }, schoolId },
            select: { id: true },
          })
        : [],
      classroomIds.length
        ? this.prisma.classroom.findMany({
            where: {
              id: { in: classroomIds.map(BigInt) },
              schoolLocation: { schoolId },
            },
            select: { id: true },
          })
        : [],
      this.prisma.role.findUnique({
        where: { name: "teacher" },
        select: { id: true },
      }),
      studentIds.length
        ? this.prisma.student.findMany({
            where: {
              id: { in: studentIds.map(BigInt) },
              schoolId,
              deletedAt: null,
            },
            select: { id: true },
          })
        : [],
    ]);

    // Cursos que ya tiene el colegio, indexados por nombre normalizado. Sin
    // esto, reimportar creaba un curso nuevo por cada nombre repetido y dejaba
    // la base llena de duplicados ("Matemática" tres veces).
    const schoolCourses = await this.prisma.course.findMany({
      where: { schoolId },
      select: { id: true, name: true },
    });
    const courseByName = new Map(
      schoolCourses.map((c) => [this.normalizeName(c.name), c.id]),
    );

    // Cualquier id que no pertenezca al colegio corta acá, antes de escribir.
    const okTeachers = new Set(validTeachers.map((t) => t.id.toString()));
    const okCourses = new Set(validCourses.map((c) => c.id.toString()));
    const okClassrooms = new Set(validClassrooms.map((c) => c.id.toString()));
    const okStudents = new Set(validStudents.map((s) => s.id.toString()));
    if (teacherIds.some((id) => !okTeachers.has(id)))
      throw new BadRequestException("Un docente no pertenece a este colegio");
    if (courseIds.some((id) => !okCourses.has(id)))
      throw new NotFoundException("Un curso no pertenece a este colegio");
    if (classroomIds.some((id) => !okClassrooms.has(id)))
      throw new NotFoundException("Un aula no pertenece a este colegio");

    // Todo dentro de una transacción: si falla a mitad (un curso duplicado, un
    // docente de otro colegio), no queda un aula creada sin sus cursos.
    //
    // timeout: el default de Prisma (5s) se queda corto. Un aula con 9 cursos
    // son ~27 escrituras y cada ida al pooler de Supabase cuesta ~180ms, así
    // que roza los 5s. Es una operación administrativa que se hace una vez al
    // conectar el colegio, no un endpoint de uso frecuente: 30s da margen para
    // un colegio con varias aulas sin dejar la transacción abierta de más.
    return this.prisma.$transaction(
      async (tx) => {
        let classroomsCreated = 0;
        let coursesCreated = 0;
        let linksCreated = 0;
        let studentsCreated = 0;
        let studentsLinked = 0;

        for (const group of groups) {
          if (!group.courses?.length) continue;

          // 1. Aula: existente (verificando que sea del colegio) o nueva.
          let classroomId: bigint;
          if (group.classroomId) {
            classroomId = BigInt(group.classroomId); // ya validada arriba
          } else {
            const name = group.newClassroomName?.trim();
            if (!name)
              throw new BadRequestException("Falta el nombre del aula");
            // Se parte "1ro B" en grado y sección. Google no los entrega por
            // separado, pero el formato peruano es consistente y dejarlos en
            // null obliga a que cada consumidor sepa manejar el vacío.
            const parsed = /^(.*?)\s*([A-Za-z])$/.exec(name);
            const created = await tx.classroom.create({
              data: {
                schoolLocationId: location.id,
                name,
                grade: parsed ? parsed[1].trim() || null : null,
                section: parsed ? parsed[2].toUpperCase() : null,
                academicYear: year,
                isActive: true,
              },
              select: { id: true },
            });
            classroomId = created.id;
            classroomsCreated++;
          }

          for (const c of group.courses) {
            // 2. Curso: existente (del colegio) o nuevo.
            let courseId: bigint;
            if (c.courseId) {
              courseId = BigInt(c.courseId); // ya validado arriba
            } else {
              const name = c.newCourseName?.trim();
              if (!name)
                throw new BadRequestException("Falta el nombre del curso");
              // Reutiliza el curso si el colegio ya tiene uno con ese nombre:
              // así reimportar es idempotente en vez de duplicar.
              const existing = courseByName.get(this.normalizeName(name));
              if (existing) {
                courseId = existing;
              } else {
                const created = await tx.course.create({
                  data: { schoolId, name },
                  select: { id: true },
                });
                courseId = created.id;
                // Se agrega al índice para que dos cursos con el mismo nombre
                // dentro de la MISMA importación tampoco se dupliquen.
                courseByName.set(this.normalizeName(name), created.id);
                coursesCreated++;
              }
            }

            // 3. Docente: debe ser docente de ESTE colegio.
            const teacherId = c.teacherId ? BigInt(c.teacherId) : null; // ya validado arriba

            // 4. Relación aula↔curso↔docente.
            const cc = await tx.classroomCourse.upsert({
              where: { classroomId_courseId: { classroomId, courseId } },
              create: { classroomId, courseId, teacherId },
              // Solo completa el docente si estaba vacío: no pisa una asignación
              // que el colegio ya hizo a mano.
              update: teacherId
                ? { teacher: { connect: { id: teacherId } } }
                : {},
              select: { id: true },
            });

            // 5. Puente con Google. Idempotente: reimportar no duplica.
            await tx.gcCourseLink.upsert({
              where: {
                schoolId_googleCourseId: {
                  schoolId,
                  googleCourseId: c.googleCourseId,
                },
              },
              create: {
                schoolId,
                googleCourseId: c.googleCourseId,
                classroomCourseId: cc.id,
              },
              update: { classroomCourseId: cc.id },
            });
            linksCreated++;

            // 6. Docente ↔ aula, para que el director sepa quién enseña dónde.
            // El rol se cargó una sola vez antes de la transacción.
            if (teacherId && teacherRole) {
              await tx.userClassroom.upsert({
                where: {
                  userId_classroomId: { userId: teacherId, classroomId },
                },
                create: {
                  userId: teacherId,
                  classroomId,
                  roleId: teacherRole.id,
                },
                update: {},
              });
            }
          }

          // ── 7. Alumnos del roster ────────────────────────────────
          // El enlace vive en gc_course_students.studentId, que el sync del
          // docente llena solo cuando el nombre calza exacto. Acá se resuelven
          // los que quedaron sueltos, y de paso se matricula al alumno en el
          // aula: sin matrícula el padre nunca vería el horario.
          for (const s of group.students ?? []) {
            let studentId: bigint | null = null;

            if (s.studentId) {
              if (!okStudents.has(s.studentId))
                throw new BadRequestException(
                  "Un alumno no pertenece a este colegio",
                );
              studentId = BigInt(s.studentId);
            } else if (s.createWithName?.trim()) {
              // Google entrega un solo campo con el nombre completo. Se parte en
              // nombre / apellidos por la primera palabra: imperfecto, pero el
              // admin puede corregirlo después en la ficha del alumno.
              const parts = s.createWithName.trim().split(/\s+/);
              const created = await tx.student.create({
                data: {
                  schoolId,
                  firstName: parts[0],
                  lastName: parts.slice(1).join(" ") || null,
                  isActive: true,
                },
                select: { id: true },
              });
              studentId = created.id;
              studentsCreated++;
            } else {
              continue; // el admin decidió ignorarlo
            }

            await tx.gcCourseStudent.updateMany({
              where: {
                googleId: s.googleId,
                course: { teacher: { userRoles: { some: { schoolId } } } },
              },
              data: { studentId },
            });
            studentsLinked++;

            await tx.studentEnrollment.upsert({
              where: {
                studentId_classroomId_academicYear: {
                  studentId,
                  classroomId,
                  academicYear: year,
                },
              },
              create: {
                studentId,
                classroomId,
                academicYear: year,
                isActive: true,
              },
              update: { isActive: true },
            });
          }
        }

        return {
          classroomsCreated,
          coursesCreated,
          linksCreated,
          studentsCreated,
          studentsLinked,
        };
      },
      { timeout: 30_000, maxWait: 10_000 },
    );
  }
}
