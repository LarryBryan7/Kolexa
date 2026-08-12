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
  async syncTeacher(userId: bigint): Promise<{ courses: number; submissions: number }> {
    const auth = await this.getAuthClientForTeacher(userId);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const classroomApi = google.classroom({ version: 'v1', auth } as any) as any;

    // Obtener schoolId del docente para el auto-match de alumnos
    const teacherRole = await this.prisma.userRole.findFirst({
      where: { userId },
      select: { schoolId: true },
    });
    const schoolId = teacherRole?.schoolId ?? null;

    const { data: coursesData } = await classroomApi.courses.list({
      teacherId: 'me',
      courseStates: ['ACTIVE'],
    });
    const courses = coursesData.courses ?? [];

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

    let totalSubmissions = 0;

    // ── Procesar los resultados (solo escrituras en BD local, rápidas) ──
    for (const { course, fetchedStudents, courseworks, submissionsByCw } of perCourse) {
      const studentCount = fetchedStudents.length;

      const gcCourse = await this.prisma.gcTeacherCourse.upsert({
        where: { teacherId_googleId: { teacherId: userId, googleId: course.id! } },
        create: { teacherId: userId, googleId: course.id!, name: course.name!, section: course.section ?? null, studentCount },
        update: { name: course.name!, section: course.section ?? null, studentCount, syncedAt: new Date() },
      });

      // Guardar roster de alumnos del curso
      for (const s of fetchedStudents) {
        const fullName: string = s.profile?.name?.fullName ?? '–';

        // Auto-match: intentar vincular con el alumno interno por nombre
        // Solo si todavía no tiene studentId asignado
        const existing = await this.prisma.gcCourseStudent.findUnique({
          where: { courseId_googleId: { courseId: gcCourse.id, googleId: s.userId } },
          select: { studentId: true },
        });

        let studentId: bigint | null = existing?.studentId ?? null;
        if (!studentId && schoolId) {
          studentId = await this._matchStudentByName(fullName, schoolId);
        }

        await this.prisma.gcCourseStudent.upsert({
          where: { courseId_googleId: { courseId: gcCourse.id, googleId: s.userId } },
          create: {
            courseId: gcCourse.id,
            googleId: s.userId,
            fullName,
            email: s.profile?.emailAddress ?? null,
            photoUrl: s.profile?.photoUrl ?? null,
            studentId,
          },
          update: {
            fullName,
            email: s.profile?.emailAddress ?? null,
            photoUrl: s.profile?.photoUrl ?? null,
            syncedAt: new Date(),
            // Solo actualizar studentId si aún no está vinculado
            ...(existing?.studentId ? {} : { studentId }),
          },
        });
      }

      // Guardar entregas (submissions) de las tareas
      for (const { cw, subs } of submissionsByCw) {
        for (const sub of subs) {
          await this.prisma.gcTeacherSubmission.upsert({
            where: {
              courseId_courseworkGoogleId_studentGoogleId: {
                courseId: gcCourse.id,
                courseworkGoogleId: cw.id!,
                studentGoogleId: sub.userId!,
              },
            },
            create: {
              courseId: gcCourse.id,
              courseworkGoogleId: cw.id!,
              courseworkTitle: cw.title!,
              studentGoogleId: sub.userId!,
              state: sub.state ?? 'TURNED_IN',
              submittedAt: sub.updateTime ? new Date(sub.updateTime) : null,
            },
            update: {
              state: sub.state ?? 'TURNED_IN',
              submittedAt: sub.updateTime ? new Date(sub.updateTime) : null,
              syncedAt: new Date(),
            },
          });
          totalSubmissions++;
        }
      }
    }

    return { courses: courses.length, submissions: totalSubmissions };
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

  async getTeacherRoster(userId: bigint) {
    const course = await this.prisma.gcTeacherCourse.findFirst({
      where: { teacherId: userId },
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
  async syncStudent(studentId: bigint): Promise<{ courses: number; courseworks: number }> {
    // ── Caché: si el último sync fue hace menos de 5 minutos, no llamamos a
    // Google de nuevo. Devolvemos los datos ya sincronizados de la BD local.
    // Optimización: en lugar de 3 consultas (findFirst + 2 counts) que el pooler
    // de Supabase serializa (~1.9s cada una = ~5.6s), hacemos UNA sola consulta
    // SQL que devuelve last_synced_at + course_count + coursework_count en una
    // sola ida al pooler (~1.9s total).
    const tCacheStart = Date.now();
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
    const tCacheMs = Date.now() - tCacheStart;
    const diffMs = lastSyncedAt ? Date.now() - lastSyncedAt.getTime() : -1;
    // TTL del caché: 15 minutos. Los datos de Classroom no cambian tan seguido
    // como para re-sync cada 5 min. Con 15 min, si el usuario espera unos minutos
    // entre syncs, el caché sigue activo y el sync es rápido (~2s) en vez de
    // volver a hacer el sync completo (~26s).
    const cacheHit = !!lastSyncedAt && diffMs < 15 * 60 * 1000;
    console.log(
      `[SYNC-DIAG] studentId=${studentId} lastCourse=${lastSyncedAt?.toISOString() ?? 'null'} ` +
        `now=${new Date().toISOString()} diffMs=${diffMs} cacheHit=${cacheHit} ` +
        `cacheQueriesMs=${tCacheMs} courses=${cachedCourses} courseworks=${cachedCourseworks}`,
    );
    if (cacheHit) {
      return { courses: cachedCourses, courseworks: cachedCourseworks };
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
    // IMPORTANTE: el pooler de Supabase usa connection_limit=1 (Prisma lo lee de la
    // URL), así que NO podemos lanzar consultas en paralelo (saturan la única
    // conexión y causan timeouts). Por eso las escrituras son SECUENCIALES.
    // Para reducir drásticamente el número de consultas:
    //  - Primero hacemos los upserts de los 9 cursos (9 consultas).
    //  - Luego un createMany GLOBAL con skipDuplicates para todos los courseworks
    //    nuevos (1 consulta) y un updateMany global para refrescar syncedAt.
    //  - Luego un createMany GLOBAL para todos los submissions nuevos (1 consulta)
    //    y un updateMany global.
    // Total ≈ 9 + 2 + 3 = 14 consultas en vez de ~60+ upserts individuales.

    // 3a. Upsert de todos los cursos (secuencial, 1 consulta por curso)
    const courseIdByGoogle = new Map<string, bigint>();
    for (const { course } of perCourse) {
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
      courseIdByGoogle.set(course.id!, gcCourse.id);
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
      // Refrescar syncedAt de todos los courseworks del estudiante (1 consulta)
      await this.prisma.gcCoursework.updateMany({
        where: { course: { studentId } },
        data: { syncedAt: new Date() },
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
      // Refrescar syncedAt de todos los submissions del estudiante (1 consulta)
      await this.prisma.gcStudentSubmission.updateMany({
        where: { coursework: { course: { studentId } } },
        data: { syncedAt: new Date() },
      });
    }

    return { courses: perCourse.length, courseworks: totalCourseworks };
  }

  // ── Retorna los cursos sincronizados del alumno ──────────
  async getCourses(studentId: bigint) {
    return this.prisma.gcCourse.findMany({
      where: { studentId },
      include: {
        courseworks: {
          orderBy: { dueDate: 'asc' },
        },
      },
      orderBy: { name: 'asc' },
    });
  }

  // ── Retorna próximas tareas (todos los cursos) ───────────
  async getUpcomingCoursework(studentId: bigint) {
    const courses = await this.prisma.gcCourse.findMany({
      where: { studentId },
      select: { id: true },
    });
    const courseIds = courses.map((c) => c.id);

    // Lunes de la semana actual en Lima (UTC-5) para incluir tareas
    // de días anteriores de la semana que siguen pendientes.
    const limaToday = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Lima' }).format(new Date());
    const limaDate = new Date(`${limaToday}T00:00:00.000-05:00`);
    const dayOfWeek = limaDate.getDay(); // 0=Dom, 1=Lun, ...
    const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
    const startOfThisWeek = new Date(limaDate.getTime() - daysToMonday * 24 * 60 * 60 * 1000);

    return this.prisma.gcCoursework.findMany({
      where: {
        courseId: { in: courseIds },
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
