// ============================================================
// Tests unitarios — alta automática de alumnos nuevos en Classroom
// ============================================================
// syncTeacher() solo ENLAZABA alumnos del roster de Google a un Student ya
// existente por nombre exacto; si el alumno era nuevo en Classroom (nunca
// existió en KOLEXA) studentId quedaba null para siempre y nunca aparecía
// para el padre/director. Estos tests cubren el fix: crear el Student que
// falta y matricularlo si el curso de Google ya está enlazado a un aula
// (gc_course_links), o si el docente tiene una sola aula asignada (respaldo,
// ya que hoy no hay pantalla para crear ese enlace).
// ============================================================

jest.mock('googleapis', () => ({
  google: {
    classroom: jest.fn(),
    auth: { OAuth2: jest.fn() },
  },
}));

import { google } from 'googleapis';
import { ClassroomService } from '../../src/modules/classroom/classroom.service';

function makeFakeClassroomApi(opts: {
  courseId: string;
  studentGoogleId: string;
  studentFullName: string;
}) {
  return {
    courses: {
      list: jest
        .fn()
        .mockResolvedValue({ data: { courses: [{ id: opts.courseId, name: 'Curso Test' }] } }),
      students: {
        list: jest.fn().mockResolvedValue({
          data: {
            students: [
              {
                userId: opts.studentGoogleId,
                profile: {
                  name: { fullName: opts.studentFullName },
                  emailAddress: 'alumno@example.com',
                  photoUrl: null,
                },
              },
            ],
          },
        }),
      },
      courseWork: {
        list: jest.fn().mockResolvedValue({ data: { courseWork: [] } }),
      },
    },
  };
}

function findRawCall(mock: jest.Mock, needle: string) {
  return mock.mock.calls.find((args: any[]) => (args[0] as string[]).join(' ').includes(needle));
}

function makeService(opts: {
  schoolId: bigint | null;
  gcCourseLinks: any[];
  existingStudents?: { id: bigint; firstName: string; lastName: string | null }[];
  teacherClassroomIds?: bigint[];
}) {
  let studentIdCounter = 500n;

  const prisma: any = {
    $queryRaw: jest.fn((strings: TemplateStringsArray) => {
      const sql = strings.join(' ');
      if (sql.includes('gc_teacher_courses')) {
        // cache-check: fuerza cacheHit=false
        return Promise.resolve([{ last_synced_at: null, course_count: 0n, submission_count: 0n }]);
      }
      if (sql.includes('INSERT INTO "students"')) {
        const id = studentIdCounter++;
        return Promise.resolve([{ id }]);
      }
      return Promise.resolve([]);
    }),
    $executeRaw: jest.fn().mockResolvedValue(undefined),
    userRole: {
      findFirst: jest.fn().mockResolvedValue(opts.schoolId ? { schoolId: opts.schoolId } : null),
    },
    student: {
      findMany: jest.fn().mockResolvedValue(opts.existingStudents ?? []),
    },
    gcTeacherCourse: {
      findMany: jest.fn().mockImplementation(({ where }: any) => {
        if (where?.googleId?.in) {
          return Promise.resolve(
            where.googleId.in.map((googleId: string, i: number) => ({ id: BigInt(i + 1), googleId })),
          );
        }
        return Promise.resolve([]);
      }),
      createMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    gcCourseLink: {
      findMany: jest.fn().mockResolvedValue(opts.gcCourseLinks),
    },
    classroomCourse: {
      findMany: jest
        .fn()
        .mockResolvedValue((opts.teacherClassroomIds ?? []).map((classroomId) => ({ classroomId }))),
    },
    gcCourseStudent: {
      findMany: jest.fn().mockResolvedValue([]),
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
  };

  const config: any = { get: jest.fn() };
  const storage: any = {};
  const service = new ClassroomService(prisma, config, storage);
  jest.spyOn(service as any, 'getAuthClientForTeacher').mockResolvedValue({});
  return { service, prisma };
}

describe('ClassroomService.syncTeacher — alta automática de alumnos nuevos', () => {
  afterEach(() => jest.clearAllMocks());

  it('crea el Student institucional cuando el alumno del roster no matchea por nombre', async () => {
    (google.classroom as jest.Mock).mockReturnValue(
      makeFakeClassroomApi({
        courseId: 'gc-course-1',
        studentGoogleId: 'gc-student-1',
        studentFullName: 'Ana Pérez',
      }),
    );
    const { service, prisma } = makeService({ schoolId: 10n, gcCourseLinks: [] });

    const result = await service.syncTeacher(1n);

    expect(result.cacheHit).toBe(false);
    expect(findRawCall(prisma.$queryRaw, 'INSERT INTO "students"')).toBeDefined();
    // Sin gc_course_links para este curso, no hay aula conocida → no matricula.
    expect(findRawCall(prisma.$executeRaw, 'student_enrollments')).toBeUndefined();
  });

  it('matricula al alumno nuevo si el curso de Google ya está enlazado a un aula institucional', async () => {
    (google.classroom as jest.Mock).mockReturnValue(
      makeFakeClassroomApi({
        courseId: 'gc-course-2',
        studentGoogleId: 'gc-student-2',
        studentFullName: 'Luis Gómez',
      }),
    );
    const { service, prisma } = makeService({
      schoolId: 10n,
      gcCourseLinks: [{ googleCourseId: 'gc-course-2', classroomCourse: { classroomId: 77n } }],
    });

    await service.syncTeacher(2n);

    expect(findRawCall(prisma.$queryRaw, 'INSERT INTO "students"')).toBeDefined();
    expect(findRawCall(prisma.$executeRaw, 'student_enrollments')).toBeDefined();
  });

  it('matricula por respaldo cuando no hay gc_course_link pero el docente tiene UNA sola aula asignada', async () => {
    (google.classroom as jest.Mock).mockReturnValue(
      makeFakeClassroomApi({
        courseId: 'gc-course-4',
        studentGoogleId: 'gc-student-4',
        studentFullName: 'Mario Rojas',
      }),
    );
    const { service, prisma } = makeService({
      schoolId: 10n,
      gcCourseLinks: [],
      teacherClassroomIds: [55n],
    });

    await service.syncTeacher(4n);

    expect(findRawCall(prisma.$queryRaw, 'INSERT INTO "students"')).toBeDefined();
    expect(findRawCall(prisma.$executeRaw, 'student_enrollments')).toBeDefined();
  });

  it('NO matricula por respaldo si el docente tiene 2+ aulas asignadas (ambiguo)', async () => {
    (google.classroom as jest.Mock).mockReturnValue(
      makeFakeClassroomApi({
        courseId: 'gc-course-5',
        studentGoogleId: 'gc-student-5',
        studentFullName: 'Carla Díaz',
      }),
    );
    const { service, prisma } = makeService({
      schoolId: 10n,
      gcCourseLinks: [],
      teacherClassroomIds: [55n, 56n],
    });

    await service.syncTeacher(5n);

    expect(findRawCall(prisma.$queryRaw, 'INSERT INTO "students"')).toBeDefined();
    expect(findRawCall(prisma.$executeRaw, 'student_enrollments')).toBeUndefined();
  });

  it('no crea Student ni consulta gc_course_links si todos los alumnos ya matchean por nombre', async () => {
    (google.classroom as jest.Mock).mockReturnValue(
      makeFakeClassroomApi({
        courseId: 'gc-course-3',
        studentGoogleId: 'gc-student-3',
        studentFullName: 'Ya Existe',
      }),
    );
    const { service, prisma } = makeService({
      schoolId: 10n,
      gcCourseLinks: [],
      existingStudents: [{ id: 999n, firstName: 'Ya', lastName: 'Existe' }],
    });

    await service.syncTeacher(3n);

    expect(prisma.gcCourseLink.findMany).not.toHaveBeenCalled();
    expect(findRawCall(prisma.$queryRaw, 'INSERT INTO "students"')).toBeUndefined();
  });
});
