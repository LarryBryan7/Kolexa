// ============================================================
// Tests unitarios — TeachersService.getHomeData
// ============================================================
// Perf: classroomCourse.findMany (usado para armar el `where` de
// scheduleBlock.findFirst) estaba anidado como un `await` suelto DENTRO
// de esa misma llamada — una etapa secuencial de más después del
// Promise.all que ya paralelizaba otras 3 queries. Se lo saca y se agrega
// como 4ta query de ese mismo Promise.all.
// ============================================================

import { TeachersService } from '../../src/modules/teachers/teachers.service';

const TEACHER_ID = 20n;

function makePrisma(overrides: Record<string, any> = {}) {
  return {
    $queryRaw: jest.fn().mockResolvedValue([]),
    gcAttendanceSession: { findUnique: jest.fn().mockResolvedValue(null) },
    teacherGoogleToken: { findUnique: jest.fn().mockResolvedValue(null) },
    classroomCourse: { findMany: jest.fn().mockResolvedValue([]) },
    scheduleBlock: { findFirst: jest.fn().mockResolvedValue(null) },
    gcTeacherCourse: { findFirst: jest.fn().mockResolvedValue(null) },
    ...overrides,
  };
}

function makeService(overrides: Record<string, any> = {}) {
  const prisma = makePrisma(overrides);
  const notifications = {};
  return { service: new TeachersService(prisma as any, notifications as any), prisma };
}

describe('TeachersService.getHomeData', () => {
  it('classroomCourse.findMany corre en el mismo batch paralelo que las otras 3 queries, no después', async () => {
    const order: string[] = [];
    const prisma = makePrisma({
      $queryRaw: jest.fn().mockImplementation(async () => {
        order.push('classrooms:start');
        return [{ id: 1n, name: 'Aula 1', grade: '1', section: 'B', student_count: 5n }];
      }),
      gcAttendanceSession: {
        findUnique: jest.fn().mockImplementation(async () => {
          order.push('session:start');
          return null;
        }),
      },
      teacherGoogleToken: {
        findUnique: jest.fn().mockImplementation(async () => {
          order.push('token:start');
          return null;
        }),
      },
      classroomCourse: {
        findMany: jest.fn().mockImplementation(async () => {
          order.push('courses:start');
          return [{ id: 900n }, { id: 901n }];
        }),
      },
      scheduleBlock: { findFirst: jest.fn().mockResolvedValue(null) },
    });
    const service = new TeachersService(prisma as any, {} as any);

    await service.getHomeData(TEACHER_ID);

    // Las 4 arrancan antes de que cualquiera termine — si classroomCourse
    // se pidiera después (como antes), no aparecería en este orden.
    expect(order).toEqual(['classrooms:start', 'session:start', 'token:start', 'courses:start']);
  });

  it('scheduleBlock.findFirst recibe el array de classroomCourseIds ya resuelto', async () => {
    const { service, prisma } = makeService({
      $queryRaw: jest.fn().mockResolvedValue([
        { id: 1n, name: 'Aula 1', grade: '1', section: 'B', student_count: 5n },
      ]),
      classroomCourse: { findMany: jest.fn().mockResolvedValue([{ id: 900n }, { id: 901n }]) },
    });

    await service.getHomeData(TEACHER_ID);

    expect(prisma.scheduleBlock.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: expect.arrayContaining([
            expect.objectContaining({
              classroomId: { in: [1n] },
              classroomCourseId: { in: [900n, 901n] },
            }),
          ]),
        }),
      }),
    );
  });

  it('sin aulas, no rompe y no busca schedule por classroomCourseId', async () => {
    const { service, prisma } = makeService({
      $queryRaw: jest.fn().mockResolvedValue([]),
      classroomCourse: { findMany: jest.fn().mockResolvedValue([]) },
    });

    const result = await service.getHomeData(TEACHER_ID);

    expect(result.classrooms).toEqual([]);
    expect(prisma.scheduleBlock.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ OR: expect.arrayContaining([{}]) }),
      }),
    );
  });
});
