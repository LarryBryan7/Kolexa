// ============================================================
// Tests unitarios — PaymentsService.getStudentObligations
// ============================================================
// Perf: mismo fix que PickupService — 3 consultas independientes ahora en
// Promise.all en vez de 3 etapas secuenciales.
// ============================================================

import { NotFoundException, ForbiddenException } from '@nestjs/common';
import { PaymentsService } from '../../src/modules/payments/payments.service';

const PARENT = { sub: 10n, roles: ['parent'] } as any;
const ADMIN = { sub: 30n, roles: ['school_admin'], schoolId: 1n } as any;
const STUDENT_ID = 100;

function makeService(overrides: Record<string, any> = {}) {
  const prisma = {
    student: { findUnique: jest.fn() },
    userStudent: { findFirst: jest.fn() },
    paymentObligation: { findMany: jest.fn().mockResolvedValue([]) },
    ...overrides,
  };
  return { service: new PaymentsService(prisma as any), prisma };
}

describe('PaymentsService.getStudentObligations', () => {
  it('alumno no encontrado → 404', async () => {
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    });
    await expect(service.getStudentObligations(STUDENT_ID, PARENT)).rejects.toThrow(NotFoundException);
  });

  it('padre sin relación con el alumno → 403, aunque las obligaciones ya se hayan traído en paralelo', async () => {
    const { service, prisma } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue(null) },
      paymentObligation: { findMany: jest.fn().mockResolvedValue([{ id: 1n, amount: 100, status: 'pending', payments: [] }]) },
    });
    await expect(service.getStudentObligations(STUDENT_ID, PARENT)).rejects.toThrow(ForbiddenException);
    expect(prisma.paymentObligation.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { studentId: STUDENT_ID } }),
    );
  });

  it('padre dueño del alumno → devuelve obligaciones con totales calculados', async () => {
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue({ id: 5n }) },
      paymentObligation: {
        findMany: jest.fn().mockResolvedValue([
          { id: 1n, amount: 100, status: 'pending', payments: [] },
          { id: 2n, amount: 50, status: 'paid', payments: [] },
        ]),
      },
    });
    const result = await service.getStudentObligations(STUDENT_ID, PARENT);
    expect(result.totalOwed).toBe(100);
    expect(result.totalPaid).toBe(50);
    expect(result.obligations).toHaveLength(2);
  });

  it('director del mismo colegio → accede sin necesitar relación con el alumno', async () => {
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue(null) },
      paymentObligation: { findMany: jest.fn().mockResolvedValue([]) },
    });
    await expect(service.getStudentObligations(STUDENT_ID, ADMIN)).resolves.toEqual(
      expect.objectContaining({ obligations: [] }),
    );
  });
});
