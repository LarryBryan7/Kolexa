// ============================================================
// Tests unitarios — PickupService.getPickupHistory
// ============================================================
// Perf: las 3 consultas (student, userStudent, pickupEvent) ahora corren
// en Promise.all en vez de 3 etapas secuenciales — ninguna depende del
// RESULTADO de otra, solo de studentId/user.sub ya conocidos. Se prueba
// que el chequeo de acceso sigue funcionando igual aplicado sobre los
// resultados ya resueltos.
// ============================================================

import { NotFoundException, ForbiddenException } from '@nestjs/common';
import { PickupService } from '../../src/modules/pickup/pickup.service';

const PARENT = { sub: 10n, roles: ['parent'] } as any;
const ADMIN = { sub: 30n, roles: ['school_admin'], schoolId: 1n } as any;
const STUDENT_ID = 100;

function makeService(overrides: Record<string, any> = {}) {
  const prisma = {
    student: { findUnique: jest.fn() },
    userStudent: { findFirst: jest.fn() },
    pickupEvent: { findMany: jest.fn().mockResolvedValue([]) },
    ...overrides,
  };
  return { service: new PickupService(prisma as any), prisma };
}

describe('PickupService.getPickupHistory', () => {
  it('alumno no encontrado → 404, sin importar el resultado de las otras consultas', async () => {
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    });
    await expect(service.getPickupHistory(STUDENT_ID, PARENT)).rejects.toThrow(NotFoundException);
  });

  it('padre sin relación con el alumno → 403, aunque el historial ya se haya traído en paralelo', async () => {
    const events = [{ id: 1n }];
    const { service, prisma } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue(null) },
      pickupEvent: { findMany: jest.fn().mockResolvedValue(events) },
    });
    await expect(service.getPickupHistory(STUDENT_ID, PARENT)).rejects.toThrow(ForbiddenException);
    // Se disparó igual (corrió en paralelo) — el punto es que nunca se
    // devuelve en la respuesta.
    expect(prisma.pickupEvent.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { studentId: STUDENT_ID } }),
    );
  });

  it('padre dueño del alumno → devuelve el historial', async () => {
    const events = [{ id: 1n }, { id: 2n }];
    const { service } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue({ id: 5n }) },
      pickupEvent: { findMany: jest.fn().mockResolvedValue(events) },
    });
    await expect(service.getPickupHistory(STUDENT_ID, PARENT)).resolves.toEqual(events);
  });

  it('director del mismo colegio → accede sin necesitar relación con el alumno', async () => {
    const events = [{ id: 1n }];
    const { service, prisma } = makeService({
      student: { findUnique: jest.fn().mockResolvedValue({ schoolId: 1n }) },
      userStudent: { findFirst: jest.fn().mockResolvedValue(null) }, // no es su hijo
      pickupEvent: { findMany: jest.fn().mockResolvedValue(events) },
    });
    await expect(service.getPickupHistory(STUDENT_ID, ADMIN)).resolves.toEqual(events);
    expect(prisma.userStudent.findFirst).toHaveBeenCalled(); // se disparó igual, en paralelo
  });
});
