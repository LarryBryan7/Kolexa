// ============================================================
// Tests unitarios — HomeworkService.getStudentHomework
// ============================================================
// Perf: mismo fix que PickupService/PaymentsService — 3 consultas
// independientes ahora en Promise.all en vez de 3 etapas secuenciales.
// ============================================================

import { NotFoundException, ForbiddenException } from '@nestjs/common';
import { HomeworkService } from '../../src/modules/homework/homework.service';

const PARENT = { sub: 10n, roles: ['parent'] } as any;
const ADMIN = { sub: 30n, roles: ['school_admin'], schoolId: 1n } as any;
const STUDENT_ID = 100;

function makeService(overrides: Record<string, any> = {}) {
  const prisma = {
    student: { findUnique: jest.fn() },
    userStudent: { findFirst: jest.fn() },
    studentHomework: { findMany: jest.fn().mockResolvedValue([]) },
    ...overrides,
  };
  return { service: new HomeworkService(prisma as any), prisma };
}

describe('HomeworkService.getStudentHomework', () => {
  it('alumno no encontrado → 404', async () => {
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    });
    await expect(service.getStudentHomework(STUDENT_ID, PARENT)).rejects.toThrow(NotFoundException);
  });

  it('padre sin relación con el alumno → 403, aunque las tareas ya se hayan traído en paralelo', async () => {
    const { service, prisma } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue(null) },
      studentHomework: { findMany: jest.fn().mockResolvedValue([{ id: 1n }]) },
    });
    await expect(service.getStudentHomework(STUDENT_ID, PARENT)).rejects.toThrow(ForbiddenException);
    expect(prisma.studentHomework.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { studentId: STUDENT_ID } }),
    );
  });

  it('padre dueño del alumno → devuelve las tareas', async () => {
    const tareas = [{ id: 1n }, { id: 2n }];
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue({ id: 5n }) },
      studentHomework: { findMany: jest.fn().mockResolvedValue(tareas) },
    });
    await expect(service.getStudentHomework(STUDENT_ID, PARENT)).resolves.toEqual(tareas);
  });

  it('director del mismo colegio → accede sin necesitar relación con el alumno', async () => {
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue(null) },
      studentHomework: { findMany: jest.fn().mockResolvedValue([]) },
    });
    await expect(service.getStudentHomework(STUDENT_ID, ADMIN)).resolves.toEqual([]);
  });
});
