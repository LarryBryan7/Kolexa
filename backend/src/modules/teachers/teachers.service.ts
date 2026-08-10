import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

const RECROO_ID = '__recreo__';

export interface AttendanceRecordInput {
  gcStudentId: number;
  status: 'present' | 'late' | 'absent';
  note?: string;
}

export interface ScheduleBlockInput {
  gcCourseId: string;   // '__recreo__' o google_id del curso
  dayOfWeek: number;    // 1=lun … 5=vie
  startTime: string;    // "HH:mm"
  endTime: string;      // "HH:mm"
}

@Injectable()
export class TeachersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async getHomeData(userId: bigint) {
    // Salones donde el docente tiene al menos un curso asignado
    const classroomRows = await this.prisma.$queryRaw<
      { id: bigint; name: string; grade: string; section: string; student_count: bigint }[]
    >`
      SELECT
        cl.id,
        cl.name,
        cl.grade,
        cl.section,
        COUNT(DISTINCT se.student_id) AS student_count
      FROM classroom_courses cc
      JOIN classrooms cl ON cl.id = cc.classroom_id
      LEFT JOIN student_enrollments se ON se.classroom_id = cl.id
      WHERE cc.teacher_id = ${userId}
      GROUP BY cl.id, cl.name, cl.grade, cl.section
      ORDER BY cl.name
    `;

    const classrooms = classroomRows.map((r) => ({
      id: Number(r.id),
      name: r.name,
      grade: r.grade,
      section: r.section,
      studentCount: Number(r.student_count),
    }));

    // Verifica si tiene bloques de horario (por owner o por classroom+course)
    const classroomIds = classroomRows.map((r) => r.id);
    const block = await this.prisma.scheduleBlock.findFirst({
      where: {
        OR: [
          { ownerId: userId },
          classroomIds.length > 0
            ? {
                classroomId: { in: classroomIds },
                classroomCourseId: {
                  in: await this.prisma.classroomCourse
                    .findMany({ where: { teacherId: userId }, select: { id: true } })
                    .then((rows) => rows.map((r) => r.id)),
                },
              }
            : {},
        ],
      },
      select: { id: true },
    });
    const hasSchedule = !!block;

    // Si no hay salones internos, busca sección y alumnos de gc_teacher_courses
    let gcSection: string | null = null;
    let gcStudentCount: number | null = null;
    if (classrooms.length === 0) {
      const gcCourse = await this.prisma.gcTeacherCourse.findFirst({
        where: { teacherId: userId },
        select: { section: true, studentCount: true },
        orderBy: { syncedAt: 'desc' },
      });
      gcSection = gcCourse?.section ?? null;
      gcStudentCount = gcCourse?.studentCount ?? null;
    }

    // Fecha en zona horaria Lima (UTC-5). new Date().toISOString() devuelve UTC,
    // lo que después de las 7pm peruana retorna la fecha de mañana.
    const todayStr = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Lima' }).format(new Date());
    const todayDate = new Date(todayStr);

    const session = await this.prisma.gcAttendanceSession.findUnique({
      where: { teacherId_date: { teacherId: userId, date: todayDate } },
      include: { records: { select: { status: true } } },
    });

    let attendanceState = 'none';
    let attendanceSummary: { present: number; late: number; absent: number; total: number } | null = null;

    if (session) {
      const photoUrls = Array.isArray(session.photoUrls) ? session.photoUrls as string[] : [];
      const present = session.records.filter((r) => r.status === 'present').length;
      const late    = session.records.filter((r) => r.status === 'late').length;
      const absent  = session.records.filter((r) => r.status === 'absent').length;
      attendanceState = photoUrls.length > 0 ? 'complete' : 'attendance_only';
      attendanceSummary = { present, late, absent, total: present + late + absent };
    }

    return { classrooms, hasSchedule, gcSection, gcStudentCount, attendanceState, attendanceSummary };
  }

  async saveAttendance(userId: bigint, date: string, records: AttendanceRecordInput[]) {
    const parsedDate = new Date(date);

    const session = await this.prisma.gcAttendanceSession.upsert({
      where: { teacherId_date: { teacherId: userId, date: parsedDate } },
      create: { teacherId: userId, date: parsedDate },
      update: {},
    });

    for (const r of records) {
      await this.prisma.gcAttendanceRecord.upsert({
        where: { sessionId_studentId: { sessionId: session.id, studentId: BigInt(r.gcStudentId) } },
        create: {
          sessionId: session.id,
          studentId: BigInt(r.gcStudentId),
          status: r.status,
          note: r.note ?? null,
        },
        update: {
          status: r.status,
          note: r.note ?? null,
        },
      });
    }

    const counts = records.reduce(
      (acc, r) => { acc[r.status] = (acc[r.status] ?? 0) + 1; return acc; },
      {} as Record<string, number>,
    );

    // Notificación personalizada por alumno al padre específico
    for (const r of records) {
      const gcStudent = await this.prisma.gcCourseStudent.findUnique({
        where: { id: BigInt(r.gcStudentId) },
        select: { id: true, fullName: true },
      });
      if (gcStudent) {
        this.notifications
          .sendAttendanceToParent(gcStudent.id, gcStudent.fullName, r.status)
          .catch(() => {});
      }
    }

    return { date, present: counts.present ?? 0, late: counts.late ?? 0, absent: counts.absent ?? 0 };
  }

  async saveSchedule(userId: bigint, blocks: ScheduleBlockInput[]) {
    if (!blocks.length) throw new BadRequestException('No hay bloques para guardar');

    // Carga los cursos GC del docente para resolver googleId → id
    const gcCourses = await this.prisma.gcTeacherCourse.findMany({
      where: { teacherId: userId },
      select: { id: true, googleId: true },
    });
    const gcMap = new Map(gcCourses.map((c) => [c.googleId, c.id]));

    // Valida que todos los gcCourseId (salvo recreo) pertenezcan al docente
    for (const b of blocks) {
      if (b.gcCourseId !== RECROO_ID && !gcMap.has(b.gcCourseId)) {
        throw new BadRequestException(`Curso no reconocido: ${b.gcCourseId}`);
      }
    }

    // Elimina bloques anteriores del docente y reemplaza
    await this.prisma.$transaction([
      this.prisma.scheduleBlock.deleteMany({ where: { ownerId: userId } }),
      this.prisma.scheduleBlock.createMany({
        data: blocks.map((b) => ({
          ownerId: userId,
          gcTeacherCourseId: b.gcCourseId === RECROO_ID ? null : gcMap.get(b.gcCourseId)!,
          type: b.gcCourseId === RECROO_ID ? 'recess' : 'class',
          dayOfWeek: b.dayOfWeek,
          startTime: new Date(`1970-01-01T${b.startTime}:00Z`),
          endTime: new Date(`1970-01-01T${b.endTime}:00Z`),
        })),
      }),
    ]);

    return { saved: blocks.length };
  }

  async saveAttendancePhotos(userId: bigint, date: string, photoUrls: string[]) {
    const parsedDate = new Date(date);
    const session = await this.prisma.gcAttendanceSession.findUnique({
      where: { teacherId_date: { teacherId: userId, date: parsedDate } },
      select: { id: true, photoUrls: true },
    });
    if (!session) throw new BadRequestException('Sesión de asistencia no encontrada para esa fecha');

    const existing = Array.isArray(session.photoUrls) ? (session.photoUrls as string[]) : [];
    const merged = [...existing, ...photoUrls];

    await this.prisma.gcAttendanceSession.update({
      where: { id: session.id },
      data: { photoUrls: merged },
    });

    // Notificar a los padres cuando hay fotos nuevas
    const newCount = photoUrls.length;
    const photoBody = newCount === 1
      ? 'Tu docente subió una foto nueva del salón'
      : `Tu docente subió ${newCount} fotos nuevas del salón`;
    this.notifications.sendToSchoolParents(userId, '📸 Fotos del salón', photoBody, { screen: 'novedades' }).catch(() => {});

    return { date, photoUrls: merged };
  }

  async getTodaySchedule(userId: bigint) {
    // Día de semana en Lima (UTC-5); getDay() usa UTC y puede devolver mañana
    const limaDateStr = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Lima' }).format(new Date());
    const day = new Date(limaDateStr).getDay(); // 0=Dom … 6=Sáb
    if (day === 0 || day === 6) return [];

    const blocks = await this.prisma.scheduleBlock.findMany({
      where: { ownerId: userId, dayOfWeek: day },
      include: { gcTeacherCourse: { select: { name: true } } },
      orderBy: { startTime: 'asc' },
    });

    return blocks.map((b) => {
      const fmt = (d: Date) =>
        new Date(d).toISOString().substring(11, 16); // "HH:mm"
      return {
        courseName: b.type === 'recess' ? 'Recreo' : (b.gcTeacherCourse?.name ?? '–'),
        type: b.type,
        startTime: fmt(b.startTime as unknown as Date),
        endTime: fmt(b.endTime as unknown as Date),
      };
    });
  }
}
