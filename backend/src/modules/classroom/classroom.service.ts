import { Injectable, NotFoundException, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { google } from 'googleapis';
import { PrismaService } from '../../prisma/prisma.service';

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

    const auth = await this.getAuthClientForTeacher(userId);
    const t2 = Date.now();
    console.log(`[TEACHER-SYNC] auth = ${t2 - t1} ms`);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const classroomApi = google.classroom({ version: 'v1', auth } as any) as any;

    // Obtener schoolId del docente para el auto-match de alumnos
    const teacherRole = await this.prisma.userRole.findFirst({
      where: { userId },
      select: { schoolId: true },
    });
    const schoolId = teacherRole?.schoolId ?? null;

    // ── Optimización (N+1): precargar UNA sola vez los estudiantes del colegio ──
    // Antes: _matchStudentByName hacía un findMany de TODOS los estudiantes por
    // cada alumno del roster (N+1 → ~30 queries pesadas). Ahora se carga 1 vez en
    // un Map<normalizedName, id>. Solo se guardan nombres con EXACTAMENTE 1 match,
    // preservando la semántica original (matches.length === 1).
    const studentsByNormalizedName = new Map<string, bigint>();
    if (schoolId) {
      const allStudents = await this.prisma.student.findMany({
        where: { schoolId, isActive: true, deletedAt: null },
        select: { id: true, firstName: true, lastName: true },
      });
      const normalize = (s: string) =>
        s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim();
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
        // 1. Roster de alumnos del curso (en paralelo con las tareas)
        let fetchedStudents: any[] = [];
        try {
          const { data: studentsData } = await classroomApi.courses.students.list({
            courseId: course.id!,
          });
          fetchedStudents = studentsData.students ?? [];
        } catch (_) {}

        // 2. Tareas publicadas del curso
        const { data: cwData } = await classroomApi.courses.courseWork.list({
          courseId: course.id!,
          courseWorkStates: ['PUBLISHED'],
        });
        const courseworks = cwData.courseWork ?? [];

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

    // 1. Upsert de cursos en lotes de 5 (connection_limit=5), como syncStudent.
    //    Devuelve el id local para construir las relaciones roster/submissions.
    for (let i = 0; i < perCourse.length; i += BATCH) {
      const batch = perCourse.slice(i, i + BATCH);
      const results = await Promise.all(
        batch.map(async ({ course, fetchedStudents }) => {
          const gcCourse = await this.prisma.gcTeacherCourse.upsert({
            where: { teacherId_googleId: { teacherId: userId, googleId: course.id! } },
            create: {
              teacherId: userId,
              googleId: course.id!,
              name: course.name!,
              section: course.section ?? null,
              studentCount: fetchedStudents.length,
            },
            update: {
              name: course.name!,
              section: course.section ?? null,
              studentCount: fetchedStudents.length,
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
    const t6 = Date.now();
    console.log(`[TEACHER-SYNC] courses-db = ${t6 - t5} ms`);

    // 2. Roster de alumnos: createMany (nuevos) + updateMany (syncedAt / studentId)
    //    por curso. El studentId se resuelve con el Map precargado (sin N+1).
    for (const { course, fetchedStudents } of perCourse) {
      const courseId = courseIdByGoogle.get(course.id!);
      if (!courseId) continue;

      const newStudents: {
        courseId: bigint;
        googleId: string;
        fullName: string;
        email: string | null;
        photoUrl: string | null;
        studentId: bigint | null;
      }[] = [];
      const existingGoogleIds: string[] = [];
      // Alumnos con match que podrían no tener studentId aún (caso marginal)
      const matchedGoogleIds: string[] = [];

      for (const s of fetchedStudents) {
        const fullName: string = s.profile?.name?.fullName ?? '–';
        const normalized = fullName.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim();
        const matchedId = studentsByNormalizedName.get(normalized) ?? null;
        newStudents.push({
          courseId,
          googleId: s.userId,
          fullName,
          email: s.profile?.emailAddress ?? null,
          photoUrl: s.profile?.photoUrl ?? null,
          studentId: matchedId,
        });
        existingGoogleIds.push(s.userId);
        if (matchedId) matchedGoogleIds.push(s.userId);
      }

      // Insertar alumnos nuevos (skipDuplicates respeta @@unique([courseId, googleId]))
      if (newStudents.length > 0) {
        await this.prisma.gcCourseStudent.createMany({
          data: newStudents,
          skipDuplicates: true,
        });
      }

      // Refrescar syncedAt de los alumnos existentes (1 query)
      if (existingGoogleIds.length > 0) {
        await this.prisma.gcCourseStudent.updateMany({
          where: { courseId, googleId: { in: existingGoogleIds } },
          data: { syncedAt: new Date() },
        });
      }

      // Asignar studentId a alumnos existentes que aún no lo tienen y ahora tienen
      // match (preserva la semántica del upsert condicional original). Caso marginal.
      if (matchedGoogleIds.length > 0) {
        for (const googleId of matchedGoogleIds) {
          const matchedId = studentsByNormalizedName.get(
            (fetchedStudents.find((s) => s.userId === googleId)?.profile?.name?.fullName ?? '')
              .toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim(),
          );
          if (matchedId) {
            await this.prisma.gcCourseStudent.updateMany({
              where: { courseId, googleId, studentId: null },
              data: { studentId: matchedId },
            });
          }
        }
      }
    }
    const t7 = Date.now();
    console.log(`[TEACHER-SYNC] roster-db = ${t7 - t6} ms`);

    // 3. Submissions: createMany (nuevos) + updateMany (syncedAt / state).
    //    El filtro de Google ya es TURNED_IN, así que state es constante.
    const allSubs: {
      courseId: bigint;
      courseworkGoogleId: string;
      courseworkTitle: string;
      studentGoogleId: string;
      state: string;
      submittedAt: Date | null;
    }[] = [];
    const subCourseIds = new Set<bigint>();
    for (const { course, submissionsByCw } of perCourse) {
      const courseId = courseIdByGoogle.get(course.id!);
      if (!courseId) continue;
      subCourseIds.add(courseId);
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

    // Insertar submissions nuevas (skipDuplicates respeta @@unique([courseId, courseworkGoogleId, studentGoogleId]))
    if (allSubs.length > 0) {
      await this.prisma.gcTeacherSubmission.createMany({
        data: allSubs,
        skipDuplicates: true,
      });
    }

    // Refrescar syncedAt de las submissions existentes (1 query, refresca TTL)
    if (subCourseIds.size > 0) {
      await this.prisma.gcTeacherSubmission.updateMany({
        where: { courseId: { in: [...subCourseIds] } },
        data: { syncedAt: new Date() },
      });
    }
    const t8 = Date.now();
    console.log(`[TEACHER-SYNC] submissions-db = ${t8 - t7} ms`);
    console.log(`[TEACHER-SYNC] total = ${Date.now() - t0} ms`);

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
  async getParentTodaySummary() {
    // Todo en hora Lima (UTC-5) para que coincida con los horarios guardados
    const LIMA_OFFSET_MS = 5 * 60 * 60 * 1000;
    const nowLima = new Date(Date.now() - LIMA_OFFSET_MS);

    const todayStr = nowLima.toISOString().split('T')[0];
    const todayDate = new Date(todayStr);

    const session = await this.prisma.gcAttendanceSession.findFirst({
      where: { date: todayDate },
      orderBy: { createdAt: 'desc' },
      include: { records: { select: { status: true } } },
    });

    const photoUrls: string[] = session && Array.isArray(session.photoUrls)
      ? (session.photoUrls as string[])
      : [];
    const photoCount = photoUrls.length;
    const arrivalStatus: string | null = session?.records[0]?.status ?? null;

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
    // Aditivo (P1-6): si se pasa courseId, devuelve el roster de ESE curso.
    // Sin courseId mantiene el comportamiento previo (primer curso) para no
    // romper AttendancePage.
    const course = await this.prisma.gcTeacherCourse.findFirst({
      where: courseId
        ? { teacherId: userId, id: courseId }
        : { teacherId: userId },
      include: { students: { orderBy: { fullName: 'asc' } } },
      orderBy: { name: 'asc' },
    });
    if (!course) return [];

    return course.students.map((s) => ({
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
  async syncStudent(studentId: bigint): Promise<{ courses: number; courseworks: number; cacheHit: boolean }> {
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
    const cacheHit = !!lastSyncedAt && diffMs < 15 * 60 * 1000;
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
      await this.prisma.gcCoursework.createMany({
        data: allCws,
        skipDuplicates: true,
      });
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
      course_name: string;
      course_section: string | null;
    };
    const [courseRows, upcomingRows] = await this.prisma.$transaction([
      this.prisma.$queryRaw<CourseRow[]>`
        SELECT c.id, c.name, c.section, c.teacher_name,
               (SELECT COUNT(*) FROM gc_coursework cw WHERE cw.course_id = c.id) AS coursework_count
        FROM gc_courses c
        WHERE c.student_id = ${studentId}
        ORDER BY c.name ASC
      `,
      this.prisma.$queryRaw<UpcomingRow[]>`
        SELECT cw.id, cw.course_id, cw.title, cw.description, cw.due_date, cw.max_points, cw.work_type,
               c.name AS course_name, c.section AS course_section
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
      course: { name: cw.course_name, section: cw.course_section },
    }));

    // sync (con caché): 1 consulta SQL adicional al pooler.
    const sync = await this.syncStudent(studentId);

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
               c.name AS course_name, c.section AS course_section
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
      course_name: string;
      course_section: string | null;
    };

    // La query de schedule_blocks depende del teacher_id de la sesión, así
    // que primero obtenemos la sesión (1 conexión) y luego el resto en una
    // transacción (1 conexión). Total 2 conexiones en vez de 4.
    const sessionRows = await this.prisma.$queryRaw<SessionRow[]>`
      SELECT s.id, s.teacher_id, s.created_at, s.photo_urls,
             (SELECT r.status FROM gc_attendance_records r WHERE r.session_id = s.id ORDER BY r.id LIMIT 1) AS status
      FROM gc_attendance_sessions s
      WHERE s.date = ${todayDate}
      ORDER BY s.created_at DESC
      LIMIT 1
    `;

    // Las 3 queries restantes se mantienen en UNA transacción (1 conexión)
    // para no cambiar el comportamiento con el pooler (connection_limit=1).
    const [blockRows, tokenRows, upcomingRows] = await this.prisma.$transaction(async (tx) => {
      const blocks = await tx.$queryRaw<BlockRow[]>`
        SELECT b.start_time, b.end_time, b.type, c.name AS course_name
        FROM schedule_blocks b
        LEFT JOIN gc_teacher_courses c ON b.gc_teacher_course_id = c.id
        WHERE b.owner_id = ${sessionRows.length > 0 ? sessionRows[0].teacher_id : 0}
          AND b.day_of_week = ${dayOfWeek}
        ORDER BY b.start_time ASC
      `;

      const tokens = await tx.$queryRaw<TokenRow[]>`SELECT id FROM google_tokens WHERE student_id = ${studentId} LIMIT 1`;

      const upcoming = await tx.$queryRaw<UpcomingRow[]>`
        SELECT cw.id, cw.course_id, cw.title, cw.description, cw.due_date, cw.max_points, cw.work_type,
               c.name AS course_name, c.section AS course_section
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
      `;

      return [blocks, tokens, upcoming] as [BlockRow[], TokenRow[], UpcomingRow[]];
    });

    // ── todaySummary ──
    const session = sessionRows[0] ?? null;
    const photoUrls: string[] = session && Array.isArray(session.photo_urls)
      ? (session.photo_urls as string[])
      : [];
    const photoCount = photoUrls.length;
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
          course: { name: cw.course_name, section: cw.course_section },
        }))
      : [];

    return { todaySummary, upcomingStatus: { connected, upcoming } };
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
