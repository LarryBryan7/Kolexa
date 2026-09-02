// ============================================================
// Tests unitarios — AttendanceService.getStudentHistory
// ============================================================
// Perf: las 2 consultas de chequeo (student, userStudent) se plegaron
// DENTRO del Promise.all de 3 que ya traía los datos (records/total/
// stats) — antes eran 2 etapas secuenciales seguidas de ese Promise.all
// de 3; ahora es un solo Promise.all de 5.
// ============================================================

import { NotFoundException, ForbiddenException } from '@nestjs/common';
import { AttendanceService } from '../../src/modules/attendance/attendance.service';

const PARENT = { sub: 10n, roles: ['parent'] } as any;
const ADMIN = { sub: 30n, roles: ['school_admin'], schoolId: 1n } as any;
const STUDENT_ID = 100;

function makeService(overrides: Record<string, any> = {}) {
  const prisma = {
    student: { findUnique: jest.fn() },
    userStudent: { findFirst: jest.fn() },
    attendanceRecord: {
      findMany: jest.fn().mockResolvedValue([]),
      count: jest.fn().mockResolvedValue(0),
      groupBy: jest.fn().mockResolvedValue([]),
    },
    ...overrides,
  };
  return { service: new AttendanceService(prisma as any), prisma };
}

describe('AttendanceService.getStudentHistory', () => {
  it('alumno no encontrado → 404', async () => {
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    });
    await expect(service.getStudentHistory(STUDENT_ID, PARENT)).rejects.toThrow(NotFoundException);
  });

  it('padre sin relación con el alumno → 403, aunque records/total/stats ya se hayan traído en paralelo', async () => {
    const { service, prisma } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue(null) },
      attendanceRecord: {
        findMany: jest.fn().mockResolvedValue([{ id: 1n }]),
        count: jest.fn().mockResolvedValue(1),
        groupBy: jest.fn().mockResolvedValue([{ status: 'present', _count: { status: 1 } }]),
      },
    });
    await expect(service.getStudentHistory(STUDENT_ID, PARENT)).rejects.toThrow(ForbiddenException);
    expect(prisma.attendanceRecord.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { studentId: STUDENT_ID } }),
    );
  });

  it('padre dueño del alumno → devuelve records/total/stats', async () => {
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue({ id: 5n }) },
      attendanceRecord: {
        findMany: jest.fn().mockResolvedValue([{ id: 1n }]),
        count: jest.fn().mockResolvedValue(1),
        groupBy: jest.fn().mockResolvedValue([{ status: 'present', _count: { status: 1 } }]),
      },
    });
    const result = await service.getStudentHistory(STUDENT_ID, PARENT);
    expect(result.total).toBe(1);
    expect(result.records).toHaveLength(1);
    expect(result.stats).toHaveLength(1);
  });

  it('director del mismo colegio → accede sin necesitar relación con el alumno', async () => {
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue(null) },
    });
    await expect(service.getStudentHistory(STUDENT_ID, ADMIN)).resolves.toEqual(
      expect.objectContaining({ total: 0 }),
    );
  });
});
