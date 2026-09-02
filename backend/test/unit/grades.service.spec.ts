// ============================================================
// Tests unitarios — GradesService.getClassroomGrades
// ============================================================
// Perf: antes hacía una query de grade.findMany POR ALUMNO (N+1) dentro
// de un Promise.all. Se reemplazó por una sola query con
// `studentId: { in }` y agrupación en memoria — se prueba que
// grade.findMany se llama exactamente 1 vez con 3+ alumnos, y que el
// agrupamiento/promedio por alumno da el mismo resultado que antes.
// ============================================================

import { GradesService } from '../../src/modules/grades/grades.service';

const CLASSROOM_ID = 900;
const PERIOD_ID = 1;
const TEACHER_ID = 20n;

function makeService(overrides: Record<string, any> = {}) {
  const prisma = {
    studentEnrollment: { findMany: jest.fn().mockResolvedValue([]) },
    grade: { findMany: jest.fn().mockResolvedValue([]) },
    ...overrides,
  };
  return { service: new GradesService(prisma as any), prisma };
}

describe('GradesService.getClassroomGrades', () => {
  it('un aula con 3 alumnos hace una sola consulta de notas (no 3), agrupadas correctamente por alumno', async () => {
    const { service, prisma } = makeService({
      studentEnrollment: {
        findMany: jest.fn().mockResolvedValue([
          { studentId: 1n, student: { id: 1n, firstName: 'Ana', lastName: 'Pérez', code: 'A1' } },
          { studentId: 2n, student: { id: 2n, firstName: 'Beto', lastName: 'García', code: 'B1' } },
          { studentId: 3n, student: { id: 3n, firstName: 'Cami', lastName: 'López', code: 'C1' } },
        ]),
      },
      grade: {
        findMany: jest.fn().mockResolvedValue([
          { studentId: 1n, grade: 15, course: { name: 'Mate' } },
          { studentId: 1n, grade: 17, course: { name: 'Comu' } },
          { studentId: 2n, grade: 10, course: { name: 'Mate' } },
          // Cami (3n) no tiene notas todavía este periodo.
        ]),
      },
    });

    const report = await service.getClassroomGrades(CLASSROOM_ID, PERIOD_ID, TEACHER_ID);

    expect(prisma.grade.findMany).toHaveBeenCalledTimes(1);
    expect(prisma.grade.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { studentId: { in: [1n, 2n, 3n] }, periodId: PERIOD_ID },
      }),
    );

    expect(report).toHaveLength(3);
    expect(report[0]).toEqual(
      expect.objectContaining({ student: expect.objectContaining({ id: 1n }), average: 16 }), // (15+17)/2
    );
    expect(report[1]).toEqual(
      expect.objectContaining({ student: expect.objectContaining({ id: 2n }), average: 10 }),
    );
    expect(report[2]).toEqual(
      expect.objectContaining({ student: expect.objectContaining({ id: 3n }), average: null, grades: [] }),
    );
  });

  it('un aula sin alumnos matriculados no consulta notas', async () => {
    const { service, prisma } = makeService({
      studentEnrollment: { findMany: jest.fn().mockResolvedValue([]) },
    });
    const report = await service.getClassroomGrades(CLASSROOM_ID, PERIOD_ID, TEACHER_ID);
    expect(report).toEqual([]);
    expect(prisma.grade.findMany).not.toHaveBeenCalled();
  });
});
