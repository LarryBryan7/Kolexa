import { Injectable, NotFoundException, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { google } from 'googleapis';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { SupabaseStorageService } from '../storage/supabase-storage.service';
import { UserPayload } from '../../common/decorators/current-user.decorator';
import { isSchoolAdminOf } from '../../common/utils/school-staff-access';

const STUDENT_SCOPES = [
  'https://www.googleapis.com/auth/classroom.courses.readonly',
  'https://www.googleapis.com/auth/classroom.course-work.readonly',
  'https://www.googleapis.com/auth/classroom.student-submissions.me.readonly',
  'https://www.googleapis.com/auth/classroom.announcements.readonly',
  'https://www.googleapis.com/auth/classroom.guardianlinks.me.readonly',
  'email',
  'profile',
];

const TEACHER_SCOPES = [
  'https://www.googleapis.com/auth/classroom.courses.readonly',
  'https://www.googleapis.com/auth/classroom.rosters.readonly',
  'https://www.googleapis.com/auth/classroom.student-submissions.students.readonly',
  'https://www.googleapis.com/auth/classroom.announcements.readonly',
  'https://www.googleapis.com/auth/classroom.topics.readonly',
  'email',
  'profile',
];

@Injectable()
export class ClassroomService {
  constructor(
    private prisma: PrismaService,
    private config: ConfigService,
    private storage: SupabaseStorageService,
  ) {}

  private createOAuthClient() {
    return new google.auth.OAuth2(
      this.config.get('GOOGLE_CLIENT_ID'),
      this.config.get('GOOGLE_CLIENT_SECRET'),
      this.config.get('GOOGLE_CALLBACK_URL'),
    );
  }

  // ── Genera la URL de autorización de Google ──────────────
  getAuthUrl(id: string, type: 'student' | 'teacher' = 'student'): string {
    const oauth2Client = this.createOAuthClient();
    const statePayload = type === 'teacher'
      ? { type: 'teacher', userId: id }
      : { type: 'student', studentId: id };
    const state = Buffer.from(JSON.stringify(statePayload)).toString('base64');
    return oauth2Client.generateAuthUrl({
      access_type: 'offline',
      scope: type === 'teacher' ? TEACHER_SCOPES : STUDENT_SCOPES,
      prompt: 'consent',
      state,
    });
  }

  // ── Maneja el callback de Google e intercambia el código ──
  async handleCallback(
    code: string,
    state: string,
  ): Promise<{ type: 'student' | 'teacher'; id: string }> {
    const parsed = JSON.parse(Buffer.from(state, 'base64').toString());
    const type: 'student' | 'teacher' = parsed.type === 'teacher' ? 'teacher' : 'student';

    const oauth2Client = this.createOAuthClient();
    const { tokens } = await oauth2Client.getToken(code);
    oauth2Client.setCredentials(tokens);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client } as any) as any;
    const { data: profile } = await oauth2.userinfo.get();

    if (type === 'teacher') {
      const userId = BigInt(parsed.userId);
      const user = await this.prisma.user.findUnique({ where: { id: userId } });
      if (!user) throw new NotFoundException('Docente no encontrado');

      await this.prisma.teacherGoogleToken.upsert({
        where: { userId },
        create: {
          userId,
          accessToken: tokens.access_token!,
          refreshToken: tokens.refresh_token!,
          expiresAt: new Date(tokens.expiry_date!),
          scope: tokens.scope!,
          googleEmail: profile.email ?? null,
        },
        update: {
          accessToken: tokens.access_token!,
          refreshToken: tokens.refresh_token ?? undefined,
          expiresAt: new Date(tokens.expiry_date!),
          scope: tokens.scope!,
          googleEmail: profile.email ?? null,
        },
      });
      return { type: 'teacher', id: String(parsed.userId) };
    }

    // Flujo alumno (existente)
    const studentId = BigInt(parsed.studentId);
    const student = await this.prisma.student.findUnique({ where: { id: studentId } });
    if (!student) throw new NotFoundException('Alumno no encontrado');

    await this.prisma.googleToken.upsert({
      where: { studentId },
      create: {
        studentId,
        accessToken: tokens.access_token!,
        refreshToken: tokens.refresh_token!,
        expiresAt: new Date(tokens.expiry_date!),
        scope: tokens.scope!,
        googleEmail: profile.email ?? null,
      },
      update: {
        accessToken: tokens.access_token!,
        refreshToken: tokens.refresh_token ?? undefined,
        expiresAt: new Date(tokens.expiry_date!),
        scope: tokens.scope!,
        googleEmail: profile.email ?? null,
      },
    });
    return { type: 'student', id: String(parsed.studentId) };
  }

  // ── Ownership del padre sobre un alumno (hallazgo BL-6) ──
  // Ninguno de los endpoints student/:studentId/* validaba que el alumno
  // perteneciera al padre autenticado — cualquier usuario con JWT válido
  // podía leer/sincronizar Classroom de un alumno ajeno (incluso de otro
  // colegio) con solo cambiar el studentId en la URL. Este guard se llama
  // desde el controller, ANTES de delegar a los métodos existentes de este
  // service (que quedan sin tocar — ver nota de alcance de la auditoría
  // sobre no modificar la lógica de OAuth/sync salvo lo estrictamente
  // necesario para cerrar el hallazgo de autorización).
  async assertStudentOwnedByParent(userId: bigint, studentId: bigint): Promise<void> {
    const rel = await this.prisma.userStudent.findFirst({
      where: { userId, studentId },
      select: { id: true },
    });
    if (!rel) {
      throw new ForbiddenException('No tienes acceso a este alumno');
    }
  }

  // ── assertStudentReadAccess ────────────────────────────────
  // Igual que assertStudentOwnedByParent, pero además deja pasar al
  // director (school_admin) del MISMO colegio del alumno. Solo se usa en
  // endpoints de LECTURA (status/courses/upcoming/overview/*-status,
  // parent/home, parent/today-summary) — auth-url, sync y avatar siguen
  // usando assertStudentOwnedByParent sin este bypass, porque son acciones
  // (disparan/renuevan la conexión OAuth del PADRE, o escriben datos), no
  // simples lecturas.
  async assertStudentReadAccess(user: UserPayload, studentId: bigint): Promise<void> {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { schoolId: true },
    });
    if (!student) throw new NotFoundException('Alumno no encontrado');
    if (isSchoolAdminOf(user, student.schoolId)) return;
    await this.assertStudentOwnedByParent(user.sub, studentId);
  }

  // ── Foto de perfil del alumno (subida por el padre) ──────
  // Bucket separado del de asistencia ('avatars', privado) — el padre
  // solo puede tocar la foto de un alumno que ya pasó por
  // assertStudentOwnedByParent() en el controller. upsert:true a
  // propósito (a diferencia de uploadPhoto() para asistencia): reemplazar
  // la foto de perfil debe pisar la anterior, no acumular archivos huérfanos.
  async uploadStudentAvatar(
    studentId: bigint,
    file: Express.Multer.File,
  ): Promise<{ avatarUrl: string }> {
    const ext = (file.originalname.split('.').pop() ?? 'jpg').toLowerCase();
    const storagePath = `${studentId}/avatar.${ext}`;

    const path = await this.storage.uploadPhoto(file, storagePath, 'avatars', true);
    if (!path) {
      throw new Error('No se pudo subir la foto');
    }

    await this.prisma.student.update({
      where: { id: studentId },
      data: { avatar: path },
    });

    const [signedUrl] = await this.storage.getSignedUrls([path], 3600, 'avatars');
    return { avatarUrl: signedUrl ?? '' };
  }

  // ── Verifica si el docente tiene cuenta conectada ────────
  async isTeacherConnected(userId: bigint): Promise<boolean> {
    const token = await this.prisma.teacherGoogleToken.findUnique({ where: { userId } });
    return !!token;
  }

  // ── Sincroniza cursos y entregas del docente ─────────────
  async syncTeacher(userId: bigint): Promise<{ courses: number; submissions: number; cacheHit: boolean }> {
    console.log('[TEACHER-SYNC] start');
    const t0 = Date.now();
    // ── Caché corta (TTL ~60s): evita llamar a Google en cada entrada/refresh.
    // El docente necesita entregas recientes, por eso el TTL es corto (a diferencia
    // de los 15 min del alumno). Una sola consulta SQL devuelve last_synced_at +
    // course_count + submission_count en una ida al pooler.
    type CacheRow = {
      last_synced_at: Date | null;
      course_count: bigint;
      submission_count: bigint;
    };
    const rows = await this.prisma.$queryRaw<CacheRow[]>`
      SELECT
        (SELECT synced_at FROM gc_teacher_courses WHERE teacher_id = ${userId} ORDER BY synced_at DESC LIMIT 1) AS last_synced_at,
        (SELECT COUNT(*) FROM gc_teacher_courses WHERE teacher_id = ${userId}) AS course_count,
        (SELECT COUNT(*) FROM gc_teacher_submissions s JOIN gc_teacher_courses c ON s.course_id = c.id WHERE c.teacher_id = ${userId}) AS submission_count
    `;
    const row = rows[0];
    const lastSyncedAt = row?.last_synced_at ?? null;
    const cachedCourses = Number(row?.course_count ?? 0);
    const cachedSubmissions = Number(row?.submission_count ?? 0);
    const diffMs = lastSyncedAt ? Date.now() - lastSyncedAt.getTime() : -1;
    const cacheHit = !!lastSyncedAt && diffMs < 60 * 1000;
    if (cacheHit) {
      return { courses: cachedCourses, submissions: cachedSubmissions, cacheHit: true };
    }
    const t1 = Date.now();
    console.log(`[TEACHER-SYNC] cache-check = ${t1 - t0} ms`);

    // ── Optimización: auth + userRole en paralelo (independientes) ──
    // auth (getAuthClientForTeacher) y userRole.findFirst no comparten datos ni
    // dependencias: auth solo necesita el token de Google del docente, userRole solo
    // lee schoolId. Se lanzan juntos con Promise.all para solapar sus round-trips.
    // student.findMany NO se incluye aquí porque depende de schoolId (de userRole).
    const [auth, teacherRole] = await Promise.all([
      this.getAuthClientForTeacher(userId),
      this.prisma.userRole.findFirst({
        where: { userId },
        select: { schoolId: true },
      }),
    ]);
    const t2 = Date.now();
    console.log(`[TEACHER-SYNC] auth+userRole = ${t2 - t1} ms`);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const classroomApi = google.classroom({ version: 'v1', auth } as any) as any;
    const schoolId = teacherRole?.schoolId ?? null;

    // ── Optimización (N+1): precargar UNA sola vez los estudiantes del colegio ──
    // Antes: _matchStudentByName hacía un findMany de TODOS los estudiantes por
    // cada alumno del roster (N+1 → ~30 queries pesadas). Ahora se carga 1 vez en
    // un Map<normalizedName, id>. Solo se guardan nombres con EXACTAMENTE 1 match,
    // preservando la semántica original (matches.length === 1).
    // student.findMany se ejecuta DESPUÉS de userRole porque necesita schoolId.
    const normalize = (s: string) =>
      s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim();
    const studentsByNormalizedName = new Map<string, bigint>();
    if (schoolId) {
      const allStudents = await this.prisma.student.findMany({
        where: { schoolId, isActive: true, deletedAt: null },
        select: { id: true, firstName: true, lastName: true },
      });
      const t2b = Date.now();
      console.log(`[TEACHER-SYNC] student.findMany = ${t2b - t2} ms`);
      const nameCount = new Map<string, number>();
      const nameToId = new Map<string, bigint>();
      for (const st of allStudents) {
        const full = normalize(`${st.firstName} ${st.lastName ?? ''}`);
        nameCount.set(full, (nameCount.get(full) ?? 0) + 1);
        nameToId.set(full, st.id);
      }
      for (const [name, count] of nameCount) {
        if (count === 1) studentsByNormalizedName.set(name, nameToId.get(name)!);
      }
      const t2c = Date.now();
      console.log(`[TEACHER-SYNC] matching = ${t2c - t2b} ms`);
    } else {
      console.log('[TEACHER-SYNC] student.findMany = 0 ms (sin schoolId)');
    }
    const t3 = Date.now();
    console.log(`[TEACHER-SYNC] student-matching = ${t3 - t2} ms`);

    const { data: coursesData } = await classroomApi.courses.list({
      teacherId: 'me',
      courseStates: ['ACTIVE'],
    });
    const courses = coursesData.courses ?? [];
    const t4 = Date.now();
    console.log(`[TEACHER-SYNC] courses-list = ${t4 - t3} ms`);

    // ── Optimización: lanzar TODAS las peticiones a Google en paralelo ──
    // Antes: por cada curso se hacían students.list + courseWork.list +
    // studentSubmissions.list (por tarea) de forma SECUENCIAL → ~30s con
    // varios cursos. Ahora se lanzan en paralelo con Promise.all → ~4-6s.
    const perCourse = await Promise.all(
      courses.map(async (course: any) => {
        // 1 + 2. Roster de alumnos y tareas publicadas del curso en paralelo (O1).
        //    Ambas llamadas dependen únicamente de course.id y son independientes entre
        //    sí, por lo que se lanzan juntas con Promise.all para solapar sus round-trips.
        //    Se preserva el try/catch de students.list (roster opcional) y el resultado.
        const [studentsResult, cwResult] = await Promise.all([
          (async () => {
            // Paginado: students.list devuelve como mucho ~pageSize alumnos por
            // llamada (nextPageToken si hay más). Sin este loop, un aula con
            // roster grande se veía silenciosamente recortada a la 1ra página.
            const fetchedStudents: any[] = [];
            try {
              let pageToken: string | undefined;
              do {
                const { data: studentsData } = await classroomApi.courses.students.list({
                  courseId: course.id!,
                  pageToken,
                });
                fetchedStudents.push(...(studentsData.students ?? []));
                pageToken = studentsData.nextPageToken ?? undefined;
              } while (pageToken);
            } catch (_) {}
            return fetchedStudents;
          })(),
          (async () => {
            const { data: cwData } = await classroomApi.courses.courseWork.list({
              courseId: course.id!,
              courseWorkStates: ['PUBLISHED'],
            });
            return cwData.courseWork ?? [];
          })(),
        ]);
        const fetchedStudents = studentsResult;
        const courseworks = cwResult;

        // 3. Entregas (submissions) de TODAS las tareas en paralelo
        const submissionsByCw = await Promise.all(
          courseworks.map(async (cw: any) => {
            try {
              const { data: subsData } = await classroomApi.courses.courseWork.studentSubmissions.list({
                courseId: course.id!,
                courseWorkId: cw.id!,
                states: ['TURNED_IN'],
              });
              return { cw, subs: subsData.studentSubmissions ?? [] };
            } catch (_) {
              return { cw, subs: [] };
            }
          }),
        );

        return { course, fetchedStudents, courseworks, submissionsByCw };
      }),
    );
    const t5 = Date.now();
    console.log(`[TEACHER-SYNC] google-data = ${t5 - t4} ms`);

    let totalSubmissions = 0;

    // ── Optimización (P2): escrituras en BD local en batch ──
    // Antes: ~135 queries secuenciales (upsert por curso + findUnique/upsert por
    // alumno + upsert por entrega) → ~15-20s. Ahora:
    //  - Cursos: upserts en lotes de 5 en paralelo (patrón syncStudent).
    //  - Roster: createMany (nuevos) + updateMany (syncedAt / studentId).
    //  - Submissions: createMany (nuevos) + updateMany (syncedAt / state).
    const courseIdByGoogle = new Map<string, bigint>();
    const BATCH = 5;

    // 1. Upsert bulk de cursos (Fase 1 — reducción de round-trips).
    //    Antes: 9 upserts individuales (cada uno = BEGIN + SELECT + INSERT/UPDATE + COMMIT).
    //    Ahora: findMany (existentes) + createMany (nuevos) + $transaction (update existentes)
    //    + findMany (IDs de los nuevos). Reduce de ~27 round-trips a ~6, preservando el id
    //    local de cada curso (googleId → id) para construir las relaciones roster/submissions.
    console.log(`[TEACHER-COURSES] start courses=${perCourse.length} batchSize=${BATCH}`);
    const c0 = Date.now();

    // 1a. Cursos existentes del docente (1 query) → Map googleId → id local
    const existingCourses = await this.prisma.gcTeacherCourse.findMany({
      where: { teacherId: userId },
      select: { id: true, googleId: true },
    });
    for (const ec of existingCourses) courseIdByGoogle.set(ec.googleId, ec.id);

    // 1b. Separar cursos nuevos vs existentes
    const newCourses = perCourse.filter(({ course }) => !courseIdByGoogle.has(course.id!));
    const existingCoursesData = perCourse
      .filter(({ course }) => courseIdByGoogle.has(course.id!))
      .map(({ course, fetchedStudents }) => ({
        googleId: course.id!,
        name: course.name!,
        section: course.section ?? null,
        studentCount: fetchedStudents.length,
      }));

    // 1c. Insertar cursos nuevos (1 query; skipDuplicates respeta @@unique([teacherId, googleId]))
    if (newCourses.length > 0) {
      await this.prisma.gcTeacherCourse.createMany({
        data: newCourses.map(({ course, fetchedStudents }) => ({
          teacherId: userId,
          googleId: course.id!,
          name: course.name!,
          section: course.section ?? null,
          studentCount: fetchedStudents.length,
        })),
        skipDuplicates: true,
      });
    }

    // 1d. Actualizar TODOS los cursos existentes en UNA sola operación con
    //     `UPDATE ... FROM (VALUES ...)`. Se usa Prisma.sql/Prisma.join para generar
    //     placeholders parametrizados: cada valor dinámico (userId, googleId, name,
    //     section, studentCount) se pasa como parámetro bind, NUNCA interpolado en el
    //     SQL → sin riesgo de SQL injection. La clave de matching es (teacherId, googleId),
    //     que corresponde a la constraint @@unique([teacherId, googleId]).
    if (existingCoursesData.length > 0) {
      const valueRows = existingCoursesData.map((c) =>
        Prisma.sql`(${userId}::bigint, ${c.googleId}::text, ${c.name}::text, ${c.section}::text, ${c.studentCount}::int)`,
      );
      await this.prisma.$executeRaw`
        UPDATE "gc_teacher_courses" AS t
        SET "name" = v.name,
            "section" = v.section,
            "student_count" = v.student_count,
            "synced_at" = NOW()
        FROM (VALUES ${Prisma.join(valueRows)}) AS v(teacher_id, google_id, name, section, student_count)
        WHERE t.teacher_id = v.teacher_id AND t.google_id = v.google_id
      `;
    }

    // 1e. Reconstruir Map googleId → id. Los IDs de los cursos EXISTENTES ya están en
    //     courseIdByGoogle (del findMany inicial 1a). Solo faltan los IDs de los cursos
    //     NUEVOS insertados en 1c, por lo que:
    //       - si NO hay cursos nuevos → NO se ejecuta ningún findMany final.
    //       - si hay cursos nuevos → findMany acotado SOLO a esos googleId.
    if (newCourses.length > 0) {
      const newIds = await this.prisma.gcTeacherCourse.findMany({
        where: {
          teacherId: userId,
          googleId: { in: newCourses.map(({ course }) => course.id!) },
        },
        select: { id: true, googleId: true },
      });
      for (const n of newIds) courseIdByGoogle.set(n.googleId, n.id);
    }

    const t6 = Date.now();
    console.log(`[TEACHER-COURSES] end total=${t6 - c0} ms`);
    console.log(`[TEACHER-SYNC] courses-db = ${t6 - t5} ms`);

    // ── Alta automática de alumnos nuevos en Classroom (P3) ──
    // Antes: si un alumno del roster de Google no matcheaba por nombre con ningún
    // Student existente, studentId quedaba null PARA SIEMPRE — el alumno nunca
    // aparecía para el padre/director aunque fuera real. Google Classroom debe
    // ALIMENTAR el modelo institucional, no reemplazarlo (mismo principio que
    // gc_course_links para cursos/horario): acá se crea el Student que falta, y
    // si el curso de Google ya está enlazado a un aula (gc_course_links →
    // classroom_courses), también se matricula ahí.
    // Solo paga el costo extra la sincronización que tiene alumnos sin match: si
    // todos matchean por nombre, unmatchedByGoogleId queda vacío y no se dispara
    // ninguna query adicional.
    const unmatchedByGoogleId = new Map<string, string>();
    for (const { fetchedStudents } of perCourse) {
      for (const s of fetchedStudents) {
        const fullName: string = s.profile?.name?.fullName ?? '–';
        const normalized = normalize(fullName);
        if (!studentsByNormalizedName.has(normalized) && !unmatchedByGoogleId.has(s.userId)) {
          unmatchedByGoogleId.set(s.userId, fullName);
        }
      }
    }
    const newlyCreatedIdByGoogleId = new Map<string, bigint>();
    if (schoolId && unmatchedByGoogleId.size > 0) {
      const entries = [...unmatchedByGoogleId.entries()];
      // Google entrega un solo campo con el nombre completo; se parte en nombre /
      // apellidos por la primera palabra, igual que en classroom-import.service.ts.
      // Imperfecto, pero el admin puede corregirlo después en la ficha del alumno.
      const studentValueRows = entries.map(([, fullName]) => {
        const parts = fullName.trim().split(/\s+/);
        const firstName = parts[0];
        const lastName = parts.slice(1).join(' ') || null;
        return Prisma.sql`(${schoolId}::bigint, ${firstName}::varchar, ${lastName}::varchar, true)`;
      });
      const created = await this.prisma.$queryRaw<{ id: bigint }[]>`
        INSERT INTO "students" (school_id, first_name, last_name, is_active)
        VALUES ${Prisma.join(studentValueRows)}
        RETURNING id
      `;
      entries.forEach(([googleId], i) => newlyCreatedIdByGoogleId.set(googleId, created[i].id));
      console.log(`[TEACHER-SYNC] alumnos-nuevos creados=${created.length}`);

      // Si el curso de Google ya está enlazado a un aula institucional, matricular
      // de una vez: sin esto el padre nunca vería el horario del alumno. Hoy no
      // existe pantalla para crear ese enlace (el endpoint de import existe pero
      // ningún cliente lo llama), así que como respaldo: si el docente tiene UNA
      // sola aula asignada (típico tutor de aula en primaria), se matricula ahí
      // sin necesitar el enlace explícito. Con 2+ aulas queda ambiguo a propósito
      // — mejor no matricular que adivinar el aula equivocada.
      const [courseLinks, teacherClassrooms] = await Promise.all([
        this.prisma.gcCourseLink.findMany({
          where: { schoolId },
          select: { googleCourseId: true, classroomCourse: { select: { classroomId: true } } },
        }),
        this.prisma.classroomCourse.findMany({
          where: { teacherId: userId },
          select: { classroomId: true },
          distinct: ['classroomId'],
        }),
      ]);
      const classroomIdByGoogleCourseId = new Map<string, bigint>();
      for (const link of courseLinks) {
        classroomIdByGoogleCourseId.set(link.googleCourseId, link.classroomCourse.classroomId);
      }
      const fallbackClassroomId = teacherClassrooms.length === 1 ? teacherClassrooms[0].classroomId : null;
      const academicYear = new Date().getFullYear();
      const enrollmentPairs = new Map<string, { studentId: bigint; classroomId: bigint }>();
      for (const { course, fetchedStudents } of perCourse) {
        const classroomId = classroomIdByGoogleCourseId.get(course.id!) ?? fallbackClassroomId;
        if (!classroomId) continue;
        for (const s of fetchedStudents) {
          const newId = newlyCreatedIdByGoogleId.get(s.userId);
          if (!newId) continue;
          enrollmentPairs.set(`${newId}:${classroomId}`, { studentId: newId, classroomId });
        }
      }
      if (enrollmentPairs.size > 0) {
        const enrollmentValueRows = [...enrollmentPairs.values()].map(
          (p) => Prisma.sql`(${p.studentId}::bigint, ${p.classroomId}::bigint, ${academicYear}::smallint, true)`,
        );
        await this.prisma.$executeRaw`
          INSERT INTO "student_enrollments" (student_id, classroom_id, academic_year, is_active)
          VALUES ${Prisma.join(enrollmentValueRows)}
          ON CONFLICT (student_id, classroom_id, academic_year) DO UPDATE SET is_active = true
        `;
        console.log(`[TEACHER-SYNC] matriculas-nuevas=${enrollmentPairs.size}`);
      }
    }

    // 2 + 3. Roster y Submissions en paralelo (Promise.all).
    //    Tras courses-db ya están disponibles todos los courseId locales (courseIdByGoogle).
    //    Roster y Submissions son INDEPENDIENTES entre sí (cada uno solo lee courseIdByGoogle
    //    y perCourse, y escribe en tablas distintas: gc_course_students vs gc_teacher_submissions),
    //    por lo que se lanzan en paralelo con Promise.all para solapar sus round-trips.
    //    Se preservan exactamente los logs y la lógica interna de cada bloque.
    const [rosterResult, submissionsResult] = await Promise.all([
      (async () => {
        // 2. Roster de alumnos (Fase 1 — reducción de round-trips).
        //    Antes: por curso se ejecutaban createMany + updateMany(syncedAt) + findMany(pending)
        //    → 9×(3+3+1) ≈ 63 round-trips. Ahora se fusionan en operaciones globales:
        //    1 createMany (todos los alumnos) + 1 updateMany (syncedAt) + 1 findMany (pending)
        //    + updates marginales de studentId. El studentId se resuelve con el Map precargado
        //    (sin N+1) y se preserva la lógica de asignación por (courseId, googleId).
        console.log('[TEACHER-ROSTER] start');
        const r0 = Date.now();
        let rTotalStudents = 0;

        // Datos globales del roster
        const allNewStudents: {
          courseId: bigint;
          googleId: string;
          fullName: string;
          email: string | null;
          photoUrl: string | null;
          studentId: bigint | null;
        }[] = [];
        const allGoogleIds: string[] = [];
        const allCourseIds: bigint[] = [];
        // Map clave compuesta "courseId:googleId" -> studentId (preserva la lógica por curso)
        const googleIdToStudentIdByCourse = new Map<string, bigint>();

        for (const { course, fetchedStudents } of perCourse) {
          const courseId = courseIdByGoogle.get(course.id!);
          if (!courseId) continue;
          allCourseIds.push(courseId);
          console.log(`[TEACHER-ROSTER] course=${course.id} students=${fetchedStudents.length}`);
          for (const s of fetchedStudents) {
            const fullName: string = s.profile?.name?.fullName ?? '–';
            const normalized = fullName.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim();
            const matchedId =
              studentsByNormalizedName.get(normalized) ?? newlyCreatedIdByGoogleId.get(s.userId) ?? null;
            allNewStudents.push({
              courseId,
              googleId: s.userId,
              fullName,
              email: s.profile?.emailAddress ?? null,
              photoUrl: s.profile?.photoUrl ?? null,
              studentId: matchedId,
            });
            allGoogleIds.push(s.userId);
            if (matchedId) googleIdToStudentIdByCourse.set(`${courseId}:${s.userId}`, matchedId);
          }
          rTotalStudents += fetchedStudents.length;
        }

        // 2a+2b. Upsert masivo de alumnos del roster en UNA sola operación.
        //     Reemplaza el createMany (nuevos) + updateMany (syncedAt) por un único
        //     INSERT ... ON CONFLICT (course_id, google_id) DO UPDATE parametrizado.
        //     - INSERT: alumnos nuevos, con su studentId (del matching) y syncedAt=NOW().
        //     - ON CONFLICT DO UPDATE: actualiza full_name/email/photo_url/synced_at de
        //       los existentes, SIN tocar student_id (preserva la semántica actual: el
        //       studentId de existentes se asigna solo vía el mecanismo de pending 2c/2d).
        //     - No elimina alumnos que ya no estén en Google Classroom.
        //     Se usa Prisma.sql/Prisma.join: todos los valores dinámicos van como
        //     parámetros bind (nunca interpolados) → sin riesgo de SQL injection.
        if (allNewStudents.length > 0) {
          const valueRows = allNewStudents.map((s) =>
            Prisma.sql`(${s.courseId}::bigint, ${s.googleId}::text, ${s.fullName}::text, ${s.email}::text, ${s.photoUrl}::text, NOW(), ${s.studentId}::bigint)`,
          );
          await this.prisma.$executeRaw`
            INSERT INTO "gc_course_students" (course_id, google_id, full_name, email, photo_url, synced_at, student_id)
            VALUES ${Prisma.join(valueRows)}
            ON CONFLICT (course_id, google_id) DO UPDATE
            SET full_name = EXCLUDED.full_name,
                email = EXCLUDED.email,
                photo_url = EXCLUDED.photo_url,
                synced_at = NOW()
          `;
        }
        const r2 = Date.now();
        console.log(`[TEACHER-ROSTER] upsert=${r2 - r0} ms`);

        // 2c. Asignar studentId solo a alumnos EXISTENTES con studentId=null que ahora
        //     tienen match (caso marginal). Los alumnos NUEVOS ya llevan studentId en el
        //     createMany, por lo que en el primer sync esta findMany devuelve [] y NO se
        //     ejecuta ningún update por alumno (elimina el N+1 de ~10.9s).
        if (googleIdToStudentIdByCourse.size > 0) {
          const pending = await this.prisma.gcCourseStudent.findMany({
            where: {
              courseId: { in: allCourseIds },
              googleId: { in: [...new Set(allGoogleIds)] },
              studentId: null,
            },
            select: { courseId: true, googleId: true },
          });
          const r3 = Date.now();
          console.log(`[TEACHER-ROSTER] pending=${r3 - r2} ms count=${pending.length}`);
          for (const p of pending) {
            const matchedId = googleIdToStudentIdByCourse.get(`${p.courseId}:${p.googleId}`);
            if (matchedId) {
              await this.prisma.gcCourseStudent.updateMany({
                where: { courseId: p.courseId, googleId: p.googleId, studentId: null },
                data: { studentId: matchedId },
              });
            }
          }
          const r4 = Date.now();
          console.log(`[TEACHER-ROSTER] studentId-updates=${r4 - r3} ms count=${pending.length}`);
        } else {
          console.log('[TEACHER-ROSTER] pending=0 ms count=0');
        }

        const t7 = Date.now();
        console.log(`[TEACHER-SYNC] roster-db = ${t7 - t6} ms`);
        console.log(`[TEACHER-ROSTER] total=${t7 - r0} ms totalStudents=${rTotalStudents}`);
        return { t7 };
      })(),
      (async () => {
        // 3. Submissions: createMany (nuevos) + updateMany (syncedAt / state).
        //    El filtro de Google ya es TURNED_IN, así que state es constante.
        const s0 = Date.now();
        const allSubs: {
          courseId: bigint;
          courseworkGoogleId: string;
          courseworkTitle: string;
          studentGoogleId: string;
          state: string;
          submittedAt: Date | null;
        }[] = [];
        for (const { course, submissionsByCw } of perCourse) {
          const courseId = courseIdByGoogle.get(course.id!);
          if (!courseId) continue;
          for (const { cw, subs } of submissionsByCw) {
            for (const sub of subs) {
              allSubs.push({
                courseId,
                courseworkGoogleId: cw.id!,
                courseworkTitle: cw.title!,
                studentGoogleId: sub.userId!,
                state: sub.state ?? 'TURNED_IN',
                submittedAt: sub.updateTime ? new Date(sub.updateTime) : null,
              });
              totalSubmissions++;
            }
          }
        }

        // Upsert masivo de submissions en UNA sola operación.
        //     Reemplaza el createMany (nuevos) + updateMany (syncedAt) por un único
        //     INSERT ... ON CONFLICT (course_id, coursework_google_id, student_google_id)
        //     DO UPDATE parametrizado.
        //     - INSERT: submissions nuevas, con syncedAt=NOW().
        //     - ON CONFLICT DO UPDATE: actualiza coursework_title/state/submitted_at/
        //       synced_at de las existentes (refresca TTL). No elimina registros.
        //     - No hay campo equivalente a studentId que deba preservarse: todos los
        //       campos de datos son seguros de sobrescribir.
        //     Se usa Prisma.sql/Prisma.join: todos los valores dinámicos van como
        //     parámetros bind (nunca interpolados) → sin riesgo de SQL injection.
        if (allSubs.length > 0) {
          const valueRows = allSubs.map((s) =>
            Prisma.sql`(${s.courseId}::bigint, ${s.courseworkGoogleId}::text, ${s.courseworkTitle}::text, ${s.studentGoogleId}::text, ${s.state}::text, ${s.submittedAt}::timestamptz, NOW())`,
          );
          await this.prisma.$executeRaw`
            INSERT INTO "gc_teacher_submissions" (course_id, coursework_google_id, coursework_title, student_google_id, state, submitted_at, synced_at)
            VALUES ${Prisma.join(valueRows)}
            ON CONFLICT (course_id, coursework_google_id, student_google_id) DO UPDATE
            SET coursework_title = EXCLUDED.coursework_title,
                state = EXCLUDED.state,
                submitted_at = EXCLUDED.submitted_at,
                synced_at = NOW()
          `;
        }
        const t8 = Date.now();
        console.log(`[TEACHER-SYNC] submissions-db = ${t8 - s0} ms`);
        return { t8 };
      })(),
    ]);
    const t9 = Date.now();
    console.log(`[TEACHER-SYNC] total = ${t9 - t0} ms`);

    return { courses: courses.length, submissions: totalSubmissions, cacheHit: false };
  }

  // ── Retorna cursos del docente sincronizados ─────────────
  async getTeacherCourses(userId: bigint) {
    return this.prisma.gcTeacherCourse.findMany({
      where: { teacherId: userId },
      include: { _count: { select: { submissions: true } } },
      orderBy: { name: 'asc' },
    });
  }

  // ── Retorna pendientes del docente (entregas sin calificar)
  async getTeacherPending(userId: bigint) {
    return this.prisma.gcTeacherSubmission.count({
      where: {
        course: { teacherId: userId },
        state: 'TURNED_IN',
      },
    });
  }

  // ── Retorna el roster de alumnos desde la BD (sincronizado en sync) ─
  // studentId es OBLIGATORIO y su ownership se valida en el controller
  // (assertStudentOwnedByParent) antes de llegar aquí.
  //
  // Antes (hallazgo BL-1 de la auditoría): el endpoint no recibía ningún
  // studentId y buscaba "la sesión de asistencia más reciente de TODA la
  // base de datos" (gcAttendanceSession.findFirst sin ningún where de
  // colegio/alumno) — devolvía datos de asistencia de CUALQUIER colegio a
  // cualquier padre autenticado, sin necesidad de conocer ningún ID. Ahora
  // se ubica la sesión a través del/los GcCourseStudent que pertenecen
  // específicamente a este alumno.
  async getParentTodaySummary(studentId: bigint) {
    // Todo en hora Lima (UTC-5) para que coincida con los horarios guardados
    const LIMA_OFFSET_MS = 5 * 60 * 60 * 1000;
    const nowLima = new Date(Date.now() - LIMA_OFFSET_MS);

    const todayStr = nowLima.toISOString().split('T')[0];
    const todayDate = new Date(todayStr);

    const gcCourseStudents = await this.prisma.gcCourseStudent.findMany({
      where: { studentId },
      select: { id: true },
    });

    const record = gcCourseStudents.length > 0
      ? await this.prisma.gcAttendanceRecord.findFirst({
          where: {
            studentId: { in: gcCourseStudents.map((s) => s.id) },
            session: { date: todayDate },
          },
          include: { session: true },
          orderBy: { session: { createdAt: 'desc' } },
        })
      : null;

    const session = record?.session ?? null;

    const storedPhotoPaths: string[] = session && Array.isArray(session.photoUrls)
      ? (session.photoUrls as string[])
      : [];
    const photoUrls = await this.storage.getSignedUrls(storedPhotoPaths);
    const photoCount = storedPhotoPaths.length;
    // record.status es el registro de ESTE alumno específico — antes se
    // tomaba records[0] de toda la sesión/aula, que no necesariamente
    // correspondía al alumno consultado.
    const arrivalStatus: string | null = record?.status ?? null;

    let arrivalTime: string | null = null;
    if (session) {
      const d = new Date(session.createdAt.getTime() - LIMA_OFFSET_MS);
      const h = d.getUTCHours();
      const m = String(d.getUTCMinutes()).padStart(2, '0');
      const ampm = h >= 12 ? 'pm' : 'am';
      const h12 = h % 12 === 0 ? 12 : h % 12;
      arrivalTime = `${h12}:${m} ${ampm}`;
    }

    const dayOfWeek = nowLima.getUTCDay();
    const currentMinutes = nowLima.getUTCHours() * 60 + nowLima.getUTCMinutes();

    let currentCourse: string | null = null;
    const scheduleBlocks: { courseName: string; startTime: string; endTime: string; isActive: boolean; type: string }[] = [];

    if (session) {
      const blocks = await this.prisma.scheduleBlock.findMany({
        where: { ownerId: session.teacherId, dayOfWeek },
        include: { gcTeacherCourse: { select: { name: true } } },
        orderBy: { startTime: 'asc' },
      });

      for (const b of blocks) {
        const start = new Date(b.startTime as unknown as Date);
        const end   = new Date(b.endTime   as unknown as Date);
        const startMins = start.getUTCHours() * 60 + start.getUTCMinutes();
        const endMins   = end.getUTCHours()   * 60 + end.getUTCMinutes();
        const isActive = currentMinutes >= startMins && currentMinutes < endMins;

        const fmt = (d: Date) => {
          const hh = d.getUTCHours();
          const mm = String(d.getUTCMinutes()).padStart(2, '0');
          return `${hh}:${mm}`;
        };

        const name = b.type === 'recess' ? 'Recreo'
          : b.type === 'break' ? 'Descanso'
          : b.type === 'lunch' ? 'Almuerzo'
          : (b.gcTeacherCourse?.name ?? 'Clase');

        if (isActive) currentCourse = name;

        scheduleBlocks.push({
          courseName: name,
          startTime: fmt(start),
          endTime: fmt(end),
          isActive,
          type: b.type,
        });
      }
    }

    return { arrivalStatus, arrivalTime, currentCourse, photoCount, photoUrls, scheduleBlocks };
  }

  async getTeacherRoster(userId: bigint, courseId?: bigint) {
    // Con courseId: el roster de ESE curso.
    //
    // Sin courseId: la UNIÓN de los alumnos de todos los cursos del docente,
    // sin repetidos. Antes se devolvía solo el primer curso alfabético, y como
    // en Classroom cada curso tiene su propio roster (a veces incompleto), la
    // pantalla de asistencia mostraba 1 alumno cuando el aula tenía 5. La
    // asistencia es del aula, no de un curso suelto.
    const courses = await this.prisma.gcTeacherCourse.findMany({
      where: courseId
        ? { teacherId: userId, id: courseId }
        : { teacherId: userId },
      include: { students: { orderBy: { fullName: 'asc' } } },
    });
    if (courses.length === 0) return [];

    // Se deduplica por googleId: el mismo alumno aparece en varios cursos con
    // filas distintas. Gana la primera, que es la que ya tiene su vínculo con
    // el alumno institucional si el sync lo emparejó.
    const seen = new Map<string, (typeof courses)[number]['students'][number]>();
    for (const c of courses) {
      for (const s of c.students) {
        if (!seen.has(s.googleId)) seen.set(s.googleId, s);
      }
    }

    return [...seen.values()]
      .sort((a, b) => a.fullName.localeCompare(b.fullName))
      .map((s) => ({
        id: Number(s.id),
        googleId: s.googleId,
        fullName: s.fullName,
        email: s.email,
        photoUrl: s.photoUrl,
      }));
  }

  // ── Construye un cliente OAuth autenticado para el docente ─
  // ── Auto-match por nombre ─────────────────────────────────
  // Busca un Student interno cuyo nombre normalizado coincida con
  // el fullName de GcCourseStudent. Devuelve null si no hay match único.
  private async _matchStudentByName(fullName: string, schoolId: bigint): Promise<bigint | null> {
    const normalize = (s: string) =>
      s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();

    const normalized = normalize(fullName);
    const students = await this.prisma.student.findMany({
      where: { schoolId, isActive: true, deletedAt: null },
      select: { id: true, firstName: true, lastName: true },
    });

    const matches = students.filter((st) => {
      const full = normalize(`${st.firstName} ${st.lastName ?? ''}`);
      return full === normalized;
    });

    return matches.length === 1 ? matches[0].id : null;
  }

  private async getAuthClientForTeacher(userId: bigint) {
    const tokenRecord = await this.prisma.teacherGoogleToken.findUnique({ where: { userId } });
    if (!tokenRecord) throw new ForbiddenException('Docente sin cuenta Google conectada');

    const oauth2Client = this.createOAuthClient();
    oauth2Client.setCredentials({
      access_token: tokenRecord.accessToken,
      refresh_token: tokenRecord.refreshToken,
      expiry_date: tokenRecord.expiresAt.getTime(),
    });

    oauth2Client.on('tokens', async (tokens) => {
      if (tokens.access_token) {
        await this.prisma.teacherGoogleToken.update({
          where: { userId },
          data: { accessToken: tokens.access_token, expiresAt: new Date(tokens.expiry_date!) },
        });
      }
    });

    return oauth2Client;
  }

  // ── Construye un cliente OAuth autenticado para el alumno ──
  private async getAuthClientForStudent(studentId: bigint) {
    const tokenRecord = await this.prisma.googleToken.findUnique({
      where: { studentId },
    });
    if (!tokenRecord) throw new ForbiddenException('Alumno sin cuenta Google conectada');

    const oauth2Client = this.createOAuthClient();
    oauth2Client.setCredentials({
      access_token: tokenRecord.accessToken,
      refresh_token: tokenRecord.refreshToken,
      expiry_date: tokenRecord.expiresAt.getTime(),
    });

    // Refresca el token automáticamente si está vencido
    oauth2Client.on('tokens', async (tokens) => {
      if (tokens.access_token) {
        await this.prisma.googleToken.update({
          where: { studentId },
          data: {
            accessToken: tokens.access_token,
            expiresAt: new Date(tokens.expiry_date!),
          },
        });
      }
    });

    return oauth2Client;
  }

  // ── Sincroniza cursos y tareas desde Google Classroom ────
  // force=true salta la caché de 15 min y sincroniza con Google sí o sí.
  // Lo usa el pull-to-refresh manual del home del padre (una acción
  // explícita del usuario pidiendo datos frescos) — las cargas automáticas
  // (abrir la app) siguen usando la caché para no pagar los ~26-30s del
  // sync completo en cada apertura (ver plan-optimizacion-sync-classroom.md).
  async syncStudent(
    studentId: bigint,
    force = false,
  ): Promise<{ courses: number; courseworks: number; cacheHit: boolean }> {
    // ── Caché: si el último sync fue hace menos de 5 minutos, no llamamos a
    // Google de nuevo. Devolvemos los datos ya sincronizados de la BD local.
    // Optimización: en lugar de 3 consultas (findFirst + 2 counts) que el pooler
    // de Supabase serializa (~1.9s cada una = ~5.6s), hacemos UNA sola consulta
    // SQL que devuelve last_synced_at + course_count + coursework_count en una
    // sola ida al pooler (~1.9s total).
    type CacheRow = {
      last_synced_at: Date | null;
      course_count: bigint;
      coursework_count: bigint;
    };
    const rows = await this.prisma.$queryRaw<CacheRow[]>`
      SELECT
        (SELECT synced_at FROM gc_courses WHERE student_id = ${studentId} ORDER BY synced_at DESC LIMIT 1) AS last_synced_at,
        (SELECT COUNT(*) FROM gc_courses WHERE student_id = ${studentId}) AS course_count,
        (SELECT COUNT(*) FROM gc_coursework cw JOIN gc_courses c ON cw.course_id = c.id WHERE c.student_id = ${studentId}) AS coursework_count
    `;
    const row = rows[0];
    const lastSyncedAt = row?.last_synced_at ?? null;
    const cachedCourses = Number(row?.course_count ?? 0);
    const cachedCourseworks = Number(row?.coursework_count ?? 0);
    const diffMs = lastSyncedAt ? Date.now() - lastSyncedAt.getTime() : -1;
    // TTL del caché: 15 minutos. Los datos de Classroom no cambian tan seguido
    // como para re-sync cada 5 min. Con 15 min, si el usuario espera unos minutos
    // entre syncs, el caché sigue activo y el sync es rápido (~2s) en vez de
    // volver a hacer el sync completo (~26s).
    const cacheHit = !force && !!lastSyncedAt && diffMs < 15 * 60 * 1000;
    if (cacheHit) {
      return { courses: cachedCourses, courseworks: cachedCourseworks, cacheHit: true };
    }

    const auth = await this.getAuthClientForStudent(studentId);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const classroomApi = google.classroom({ version: 'v1', auth } as any) as any;

    // 1. Traer cursos activos del alumno
    const { data: coursesData } = await classroomApi.courses.list({
      studentId: 'me',
      courseStates: ['ACTIVE'],
    });
    const courses = coursesData.courses ?? [];

    // 2. Lanzar TODAS las peticiones a Google en paralelo (courseWork + submissions
    // de cada curso) para reducir el tiempo de ~30s a ~4-6s.
    const perCourse = await Promise.all(
      courses.map(async (course: any) => {
        const [cwRes, subRes] = await Promise.all([
          classroomApi.courses.courseWork.list({
            courseId: course.id!,
            courseWorkStates: ['PUBLISHED'],
          }),
          classroomApi.courses.courseWork.studentSubmissions.list({
            courseId: course.id!,
            courseWorkId: '-',
            userId: 'me',
          }),
        ]);
        return {
          course,
          courseworks: cwRes.data.courseWork ?? [],
          submissions: subRes.data.studentSubmissions ?? [],
        };
      }),
    );

    let totalCourseworks = 0;

    // 3. Procesar los resultados (escrituras en BD local).
    // IMPORTANTE: el pooler de Supabase usa connection_limit=5 (Prisma lo lee de la
    // URL), así que podemos lanzar consultas en paralelo en lotes de máximo 5
    // (no saturan las conexiones). Por eso los upserts de cursos van por lotes.
    // Para reducir drásticamente el número de consultas:
    //  - Primero hacemos los upserts de los 9 cursos (9 consultas).
    //  - Luego un createMany GLOBAL con skipDuplicates para todos los courseworks
    //    nuevos (1 consulta) y un updateMany global para refrescar syncedAt.
    //  - Luego un createMany GLOBAL para todos los submissions nuevos (1 consulta)
    //    y un updateMany global.
    // Total ≈ 9 + 2 + 3 = 14 consultas en vez de ~60+ upserts individuales.

    // 3a. Upsert de todos los cursos en lotes de máximo 5 (connection_limit=5).
    //     9 cursos → 2 lotes (5+4) en vez de 9 round-trips secuenciales.
    const courseIdByGoogle = new Map<string, bigint>();
    const BATCH = 5;
    for (let i = 0; i < perCourse.length; i += BATCH) {
      const batch = perCourse.slice(i, i + BATCH);
      const results = await Promise.all(
        batch.map(async ({ course }) => {
          const gcCourse = await this.prisma.gcCourse.upsert({
            where: { studentId_googleId: { studentId, googleId: course.id! } },
            create: {
              studentId,
              googleId: course.id!,
              name: course.name!,
              section: course.section ?? null,
              teacherName: course.teacherFolder?.title ?? null,
            },
            update: {
              name: course.name!,
              section: course.section ?? null,
              syncedAt: new Date(),
            },
          });
          return { googleId: course.id!, id: gcCourse.id };
        }),
      );
      for (const r of results) {
        courseIdByGoogle.set(r.googleId, r.id);
      }
    }

    // 3b. Courseworks: createMany global con skipDuplicates (inserta solo los nuevos)
    const allCws: {
      courseId: bigint;
      googleId: string;
      title: string;
      description: string | null;
      dueDate: Date | null;
      maxPoints: number | null;
      workType: string;
      state: string;
      alternateLink: string | null;
    }[] = [];
    for (const { course, courseworks } of perCourse) {
      const courseId = courseIdByGoogle.get(course.id!);
      if (!courseId) continue;
      for (const cw of courseworks) {
        allCws.push({
          courseId,
          googleId: cw.id!,
          title: cw.title!,
          description: cw.description ?? null,
          dueDate: this.parseDueDate(cw.dueDate, cw.dueTime),
          maxPoints: cw.maxPoints ?? null,
          workType: cw.workType ?? 'ASSIGNMENT',
          state: cw.state ?? 'PUBLISHED',
          alternateLink: cw.alternateLink ?? null,
        });
        totalCourseworks++;
      }
    }
    if (allCws.length > 0) {
      // INSERT ... ON CONFLICT DO UPDATE en 1 sola consulta: antes esto era
      // un createMany con skipDuplicates, que solo insertaba tareas NUEVAS y
      // dejaba intactas (nunca actualizaba) las que ya existían — si el
      // docente cambiaba la fecha de entrega, el título o los puntos de una
      // tarea ya sincronizada, ese cambio nunca llegaba a la BD de Kolexa
      // por más veces que se volviera a sincronizar. ON CONFLICT DO UPDATE
      // corrige eso sin perder el ahorro de 1 sola ida al pooler.
      const valueRows = allCws.map(
        (cw) =>
          Prisma.sql`(${cw.courseId}, ${cw.googleId}, ${cw.title}, ${cw.description}, ${cw.dueDate}, ${cw.maxPoints}, ${cw.workType}, ${cw.state}, ${cw.alternateLink}, NOW())`,
      );
      await this.prisma.$executeRaw`
        INSERT INTO gc_coursework (course_id, google_id, title, description, due_date, max_points, work_type, state, alternate_link, synced_at)
        VALUES ${Prisma.join(valueRows)}
        ON CONFLICT (course_id, google_id) DO UPDATE SET
          title = EXCLUDED.title,
          description = EXCLUDED.description,
          due_date = EXCLUDED.due_date,
          max_points = EXCLUDED.max_points,
          work_type = EXCLUDED.work_type,
          state = EXCLUDED.state,
          alternate_link = EXCLUDED.alternate_link,
          synced_at = EXCLUDED.synced_at
      `;
    }

    // 3c. Submissions: mapa googleId→id de courseworks del estudiante (1 consulta)
    const allSubs: {
      courseworkId: bigint;
      googleId: string;
      submissionState: string;
      assignedGrade: number | null;
    }[] = [];
    const cwsOfStudent = await this.prisma.gcCoursework.findMany({
      where: { course: { studentId } },
      select: { id: true, googleId: true },
    });
    const cwIdByGoogle = new Map(cwsOfStudent.map((c) => [c.googleId, c.id]));

    for (const { submissions } of perCourse) {
      for (const sub of submissions) {
        const cwId = cwIdByGoogle.get(sub.courseWorkId!);
        if (!cwId) continue;
        allSubs.push({
          courseworkId: cwId,
          googleId: sub.id!,
          submissionState: sub.state ?? 'NEW',
          assignedGrade: sub.assignedGrade ?? null,
        });
      }
    }
    if (allSubs.length > 0) {
      await this.prisma.gcStudentSubmission.createMany({
        data: allSubs,
        skipDuplicates: true,
      });
    }

    return { courses: perCourse.length, courseworks: totalCourseworks, cacheHit: false };
  }

  // ── Retorna los cursos sincronizados del alumno ──────────
  // Optimizado: usa _count en lugar de cargar todos los courseworks
  // (la vista solo necesita el número de tareas por curso).
  async getCourses(studentId: bigint) {
    return this.prisma.gcCourse.findMany({
      where: { studentId },
      select: {
        id: true,
        name: true,
        section: true,
        teacherName: true,
        _count: { select: { courseworks: true } },
      },
      orderBy: { name: 'asc' },
    });
  }

  // ── Vista combinada para la app (1 sola petición HTTP) ──
  // Devuelve connected + sync (con caché) + courses + upcoming en UNA
  // sola respuesta. Reduce de 4 requests HTTP a 1, ahorrando el overhead
  // de red de Railway (~1.5s por request).
  async getOverview(studentId: bigint) {
    // isConnected: 1 consulta ligera al pooler
    const token = await this.prisma.googleToken.findUnique({
      where: { studentId },
      select: { id: true },
    });
    const connected = !!token;
    if (!connected) {
      return { connected: false, courses: [], upcoming: [], sync: { courses: 0, courseworks: 0 } };
    }

    // Lunes de la semana actual en Lima (UTC-5) para incluir tareas
    // de días anteriores de la semana que siguen pendientes.
    const limaToday = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Lima' }).format(new Date());
    const limaDate = new Date(`${limaToday}T00:00:00.000-05:00`);
    const dayOfWeek = limaDate.getDay(); // 0=Dom, 1=Lun, ...
    const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const startOfThisWeek = new Date(limaDate.getTime() - daysToMonday * 24 * 60 * 60 * 1000);

    // courses + upcoming en UNA transacción (2 $queryRaw en 1 conexión).
    // Con el pooler de Supabase (connection_limit=1), ejecutar las consultas
    // en una sola transacción evita el overhead de abrir 2 conexiones.
    type CourseRow = {
      id: bigint;
      name: string;
      section: string | null;
      teacher_name: string | null;
      coursework_count: bigint;
    };
    type UpcomingRow = {
      id: bigint;
      course_id: bigint;
      title: string;
      description: string | null;
      due_date: Date | null;
      max_points: number | null;
      work_type: string;
      alternate_link: string | null;
      course_name: string;
      course_section: string | null;
    };
    // El sync (abajo) no depende de este resultado, y la respuesta ya se
    // arma con lo que hay en la BD *antes* de sincronizar (el sync fresco
    // se ve recién en la siguiente llamada) — por eso correr ambos en
    // paralelo no cambia qué se devuelve, solo evita esperar la suma de los
    // dos tiempos en vez del máximo (relevante sobre todo cuando el caché
    // del sync expiró y toca llamar a la API de Classroom, ~26s).
    const [[courseRows, upcomingRows], sync] = await Promise.all([
      this.prisma.$transaction([
        this.prisma.$queryRaw<CourseRow[]>`
          SELECT c.id, c.name, c.section, c.teacher_name,
                 (SELECT COUNT(*) FROM gc_coursework cw WHERE cw.course_id = c.id) AS coursework_count
          FROM gc_courses c
          WHERE c.student_id = ${studentId}
          ORDER BY c.name ASC
        `,
        this.prisma.$queryRaw<UpcomingRow[]>`
          SELECT cw.id, cw.course_id, cw.title, cw.description, cw.due_date, cw.max_points, cw.work_type,
                 cw.alternate_link, c.name AS course_name, c.section AS course_section
          FROM gc_coursework cw
          JOIN gc_courses c ON cw.course_id = c.id
          WHERE c.student_id = ${studentId}
            AND cw.state = 'PUBLISHED'
            AND cw.work_type != 'MATERIAL'
            AND (cw.due_date >= ${startOfThisWeek} OR cw.due_date IS NULL)
            AND NOT EXISTS (
              SELECT 1 FROM gc_student_submissions s
              WHERE s.coursework_id = cw.id
                AND (s.submission_state IN ('TURNED_IN','RETURNED') OR s.assigned_grade IS NOT NULL)
            )
          ORDER BY cw.due_date ASC NULLS LAST
          LIMIT 20
        `,
      ]),
      this.syncStudent(studentId),
    ]);

    const courses = courseRows.map((c) => ({
      id: c.id.toString(),
      name: c.name,
      section: c.section,
      teacherName: c.teacher_name,
      _count: { courseworks: Number(c.coursework_count) },
    }));
    const upcoming = upcomingRows.map((cw) => ({
      id: cw.id.toString(),
      courseId: cw.course_id.toString(),
      title: cw.title,
      description: cw.description,
      dueDate: cw.due_date,
      maxPoints: cw.max_points,
      workType: cw.work_type,
      alternateLink: cw.alternate_link,
      course: { name: cw.course_name, section: cw.course_section },
    }));

    return { connected: true, courses, upcoming, sync };
  }

  // ── Retorna próximas tareas (todos los cursos) ───────────
  // Optimizado: una sola consulta usando la relación course.studentId
  // en lugar de 2 consultas (evita un round-trip extra al pooler).
  async getUpcomingCoursework(studentId: bigint) {
    // Lunes de la semana actual en Lima (UTC-5) para incluir tareas
    // de días anteriores de la semana que siguen pendientes.
    const limaToday = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Lima' }).format(new Date());
    const limaDate = new Date(`${limaToday}T00:00:00.000-05:00`);
    const dayOfWeek = limaDate.getDay(); // 0=Dom, 1=Lun, ...
    const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const startOfThisWeek = new Date(limaDate.getTime() - daysToMonday * 24 * 60 * 60 * 1000);

    return this.prisma.gcCoursework.findMany({
      where: {
        course: { studentId },
        state: 'PUBLISHED',
        workType: { not: 'MATERIAL' },
        OR: [
          { dueDate: { gte: startOfThisWeek } },
          { dueDate: null },
        ],
        // Excluir si el alumno ya entregó, fue calificado, o el profesor asignó nota
        // (Google no siempre cambia el state a RETURNED cuando el profesor califica)
        NOT: {
          submissions: {
            some: {
              OR: [
                { submissionState: { in: ['TURNED_IN', 'RETURNED'] } },
                { assignedGrade: { not: null } },
              ],
            },
          },
        },
      },
      include: { course: { select: { name: true, section: true } } },
      orderBy: [{ dueDate: { sort: 'asc', nulls: 'last' } }],
      take: 20,
    });
  }

  // ── Verifica si el alumno tiene cuenta conectada ─────────
  // ── Vista ligera para el card "Esta semana" del home del padre ─
  // Devuelve connected + upcoming en UNA sola petición, sin courses ni
  // sync. Es más rápido que /overview porque no ejecuta syncStudent ni la
  // query de courses (que el card no necesita).
  //
  // La verificación de conexión y la query de upcoming se ejecutan en una
  // sola transacción ($transaction con 2 $queryRaw) para evitar el overhead
  // de abrir 2 conexiones al pooler de Supabase (connection_limit=1).
  async getUpcomingStatus(studentId: bigint) {
    type TokenRow = { id: bigint };
    type UpcomingRow = {
      id: bigint;
      course_id: bigint;
      title: string;
      description: string | null;
      due_date: Date | null;
      max_points: number | null;
      work_type: string;
      alternate_link: string | null;
      course_name: string;
      course_section: string | null;
    };

    const limaToday = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Lima' }).format(new Date());
    const limaDate = new Date(`${limaToday}T00:00:00.000-05:00`);
    const dayOfWeek = limaDate.getDay(); // 0=Dom, 1=Lun, ...
    const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const startOfThisWeek = new Date(limaDate.getTime() - daysToMonday * 24 * 60 * 60 * 1000);

    const [tokenRows, upcomingRows] = await this.prisma.$transaction([
      this.prisma.$queryRaw<TokenRow[]>`SELECT id FROM google_tokens WHERE student_id = ${studentId} LIMIT 1`,
      this.prisma.$queryRaw<UpcomingRow[]>`
        SELECT cw.id, cw.course_id, cw.title, cw.description, cw.due_date, cw.max_points, cw.work_type,
               cw.alternate_link, c.name AS course_name, c.section AS course_section
        FROM gc_coursework cw
        JOIN gc_courses c ON cw.course_id = c.id
        WHERE c.student_id = ${studentId}
          AND cw.state = 'PUBLISHED'
          AND cw.work_type != 'MATERIAL'
          AND (cw.due_date >= ${startOfThisWeek} OR cw.due_date IS NULL)
          AND NOT EXISTS (
            SELECT 1 FROM gc_student_submissions s
            WHERE s.coursework_id = cw.id
              AND (s.submission_state IN ('TURNED_IN','RETURNED') OR s.assigned_grade IS NOT NULL)
          )
        ORDER BY cw.due_date ASC NULLS LAST
        LIMIT 20
      `,
    ]);

    const connected = tokenRows.length > 0;
    if (!connected) {
      return { connected: false, upcoming: [] };
    }

    const upcoming = upcomingRows.map((cw) => ({
      id: cw.id.toString(),
      courseId: cw.course_id.toString(),
      title: cw.title,
      description: cw.description,
      dueDate: cw.due_date,
      maxPoints: cw.max_points,
      workType: cw.work_type,
      alternateLink: cw.alternate_link,
      course: { name: cw.course_name, section: cw.course_section },
    }));

    return { connected: true, upcoming };
  }

  // ── Vista combinada del home del padre ───────────────────
  // Devuelve todaySummary + upcomingStatus en UNA sola petición, ejecutando
  // TODAS las queries en una sola transacción $transaction. Con el pooler de
  // Supabase (connection_limit=1), esto evita que las queries de los cards
  // "Novedades" y "Esta semana" compitan por la única conexión y se
  // serialicen (lo que alargaba el tiempo total a ~7s).
  async getParentHome(studentId: bigint) {
    const LIMA_OFFSET_MS = 5 * 60 * 60 * 1000;
    const nowLima = new Date(Date.now() - LIMA_OFFSET_MS);
    const todayStr = nowLima.toISOString().split('T')[0];
    const todayDate = new Date(todayStr);
    const dayOfWeek = nowLima.getUTCDay();
    const currentMinutes = nowLima.getUTCHours() * 60 + nowLima.getUTCMinutes();

    const limaToday = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Lima' }).format(new Date());
    const limaDate = new Date(`${limaToday}T00:00:00.000-05:00`);
    const daysToMonday = limaDate.getDay() === 0 ? 6 : limaDate.getDay() - 1;
    const startOfThisWeek = new Date(limaDate.getTime() - daysToMonday * 24 * 60 * 60 * 1000);

    type SessionRow = {
      id: bigint;
      teacher_id: bigint;
      created_at: Date;
      photo_urls: unknown;
      status: string | null;
    };
    type BlockRow = {
      start_time: Date;
      end_time: Date;
      type: string;
      course_name: string | null;
    };
    type TokenRow = { id: bigint };
    type UpcomingRow = {
      id: bigint;
      course_id: bigint;
      title: string;
      description: string | null;
      due_date: Date | null;
      max_points: number | null;
      work_type: string;
      alternate_link: string | null;
      course_name: string;
      course_section: string | null;
      institutional_course_id: bigint | null;
      teacher_name: string | null;
    };

    // La query de schedule_blocks depende del teacher_id de la sesión, así
    // que primero obtenemos la sesión (1 conexión) y luego el resto en una
    // transacción (1 conexión). Total 2 conexiones en vez de 4. La consulta
    // del avatar es independiente (solo necesita studentId) — corre en
    // paralelo con la de la sesión.
    const [sessionRows, studentForAvatar] = await Promise.all([
      this.prisma.$queryRaw<SessionRow[]>`
        SELECT s.id, s.teacher_id, s.created_at, s.photo_urls,
               (SELECT r.status FROM gc_attendance_records r WHERE r.session_id = s.id ORDER BY r.id LIMIT 1) AS status
        FROM gc_attendance_sessions s
        WHERE s.date = ${todayDate}
        ORDER BY s.created_at DESC
        LIMIT 1
      `,
      this.prisma.student.findUnique({ where: { id: studentId }, select: { avatar: true } }),
    ]);

    // Las 3 queries restantes se mantienen en UNA transacción (1 conexión)
    // para no cambiar el comportamiento con el pooler. Firmar el avatar no
    // toca la base (es una llamada a la API de Storage) — corre en paralelo.
    const [[blockRows, tokenRows, upcomingRows], avatarUrls] = await Promise.all([
      this.prisma.$transaction(async (tx) => {
      // Fuente principal: el horario del AULA en la que está matriculado el
      // alumno. Es el que carga el colegio (importación por foto) y el único
      // que cubre bloques sin curso — recreo, tutoría, salida — que el horario
      // por docente no puede representar.
      let blocks = await tx.$queryRaw<BlockRow[]>`
        SELECT b.start_time, b.end_time, b.type,
               COALESCE(co.name, b.label) AS course_name
        FROM schedule_blocks b
        JOIN student_enrollments e
          ON e.classroom_id = b.classroom_id
         AND e.student_id = ${studentId}
         AND e.is_active = true
        LEFT JOIN classroom_courses cc ON b.classroom_course_id = cc.id
        LEFT JOIN courses co ON cc.course_id = co.id
        WHERE b.day_of_week = ${dayOfWeek}
        ORDER BY b.start_time ASC
      `;

      // Respaldo: horario cargado por el docente (modelo anterior). Solo si el
      // colegio todavía no cargó el del aula, para no dejar al padre sin nada.
      if (blocks.length === 0) {
        blocks = await tx.$queryRaw<BlockRow[]>`
          SELECT b.start_time, b.end_time, b.type, c.name AS course_name
          FROM schedule_blocks b
          LEFT JOIN gc_teacher_courses c ON b.gc_teacher_course_id = c.id
          WHERE b.owner_id = ${sessionRows.length > 0 ? sessionRows[0].teacher_id : 0}
            AND b.day_of_week = ${dayOfWeek}
          ORDER BY b.start_time ASC
        `;
      }

      const tokens = await tx.$queryRaw<TokenRow[]>`SELECT id FROM google_tokens WHERE student_id = ${studentId} LIMIT 1`;

      // El LEFT JOIN por gc_course_links resuelve la tarea de Google al curso
      // institucional y a su docente. Es LEFT y no JOIN a propósito: si el
      // colegio todavía no vinculó ese curso, la tarea igual se muestra con el
      // nombre que trae Google. El puente enriquece, nunca filtra.
      const upcoming = await tx.$queryRaw<UpcomingRow[]>`
        SELECT cw.id, cw.course_id, cw.title, cw.description, cw.due_date, cw.max_points, cw.work_type,
               cw.alternate_link,
               COALESCE(ico.name, c.name) AS course_name,
               c.section AS course_section,
               ico.id AS institutional_course_id,
               NULLIF(TRIM(CONCAT(t.first_name, ' ', COALESCE(t.last_name, ''))), '') AS teacher_name
        FROM gc_coursework cw
        JOIN gc_courses c ON cw.course_id = c.id
        LEFT JOIN gc_course_links gl ON gl.google_course_id = c.google_id
        LEFT JOIN classroom_courses ccx ON gl.classroom_course_id = ccx.id
        LEFT JOIN courses ico ON ccx.course_id = ico.id
        LEFT JOIN users t ON ccx.teacher_id = t.id
        WHERE c.student_id = ${studentId}
          AND cw.state = 'PUBLISHED'
          AND cw.work_type != 'MATERIAL'
          AND (cw.due_date >= ${startOfThisWeek} OR cw.due_date IS NULL)
          AND NOT EXISTS (
            SELECT 1 FROM gc_student_submissions s
            WHERE s.coursework_id = cw.id
              AND (s.submission_state IN ('TURNED_IN','RETURNED') OR s.assigned_grade IS NOT NULL)
          )
        ORDER BY cw.due_date ASC NULLS LAST
        LIMIT 20
      `;

        return [blocks, tokens, upcoming] as [BlockRow[], TokenRow[], UpcomingRow[]];
      }),
      studentForAvatar?.avatar
        ? this.storage.getSignedUrls([studentForAvatar.avatar], 3600, 'avatars')
        : Promise.resolve([]),
    ]);
    const avatarUrl = avatarUrls[0] ?? null;

    // ── todaySummary ──
    const session = sessionRows[0] ?? null;
    const storedPhotoPaths: string[] = session && Array.isArray(session.photo_urls)
      ? (session.photo_urls as string[])
      : [];
    const photoUrls = await this.storage.getSignedUrls(storedPhotoPaths);
    const photoCount = storedPhotoPaths.length;
    const arrivalStatus: string | null = session?.status ?? null;

    let arrivalTime: string | null = null;
    if (session) {
      const d = new Date(session.created_at.getTime() - LIMA_OFFSET_MS);
      const h = d.getUTCHours();
      const m = String(d.getUTCMinutes()).padStart(2, '0');
      const ampm = h >= 12 ? 'pm' : 'am';
      const h12 = h % 12 === 0 ? 12 : h % 12;
      arrivalTime = `${h12}:${m} ${ampm}`;
    }

    let currentCourse: string | null = null;
    const scheduleBlocks: { courseName: string; startTime: string; endTime: string; isActive: boolean; type: string }[] = [];
    for (const b of blockRows) {
      const start = new Date(b.start_time);
      const end = new Date(b.end_time);
      const startMins = start.getUTCHours() * 60 + start.getUTCMinutes();
      const endMins = end.getUTCHours() * 60 + end.getUTCMinutes();
      const isActive = currentMinutes >= startMins && currentMinutes < endMins;
      const fmt = (d: Date) => {
        const hh = d.getUTCHours();
        const mm = String(d.getUTCMinutes()).padStart(2, '0');
        return `${hh}:${mm}`;
      };
      const name = b.type === 'recess' ? 'Recreo'
        : b.type === 'break' ? 'Descanso'
        : b.type === 'lunch' ? 'Almuerzo'
        : (b.course_name ?? 'Clase');
      if (isActive) currentCourse = name;
      scheduleBlocks.push({
        courseName: name,
        startTime: fmt(start),
        endTime: fmt(end),
        isActive,
        type: b.type,
      });
    }

    const todaySummary = { arrivalStatus, arrivalTime, currentCourse, photoCount, photoUrls, scheduleBlocks };

    // ── upcomingStatus ──
    const connected = tokenRows.length > 0;
    const upcoming = connected
      ? upcomingRows.map((cw) => ({
          id: cw.id.toString(),
          courseId: cw.course_id.toString(),
          title: cw.title,
          description: cw.description,
          dueDate: cw.due_date,
          maxPoints: cw.max_points,
          workType: cw.work_type,
          alternateLink: cw.alternate_link,
          course: {
            name: cw.course_name,
            section: cw.course_section,
            // Presentes solo si el colegio ya vinculó el curso de Classroom con
            // el suyo. El cliente los usa si vienen y los ignora si no.
            institutionalId: cw.institutional_course_id?.toString() ?? null,
            teacherName: cw.teacher_name,
          },
        }))
      : [];

    return { todaySummary, upcomingStatus: { connected, upcoming }, avatarUrl };
  }

  async isConnected(studentId: bigint): Promise<boolean> {
    const token = await this.prisma.googleToken.findUnique({
      where: { studentId },
    });
    return !!token;
  }

  private parseDueDate(
    dueDate?: { year?: number; month?: number; day?: number } | null,
    dueTime?: { hours?: number; minutes?: number } | null,
  ): Date | null {
    if (!dueDate?.year) return null;
    // Google Classroom devuelve dueDate/dueTime en UTC — usar Date.UTC para
    // evitar que el constructor local del servidor añada el offset de Lima.
    return new Date(Date.UTC(
      dueDate.year,
      (dueDate.month ?? 1) - 1,
      dueDate.day ?? 1,
      dueTime?.hours ?? 23,
      dueTime?.minutes ?? 59,
    ));
  }
}
