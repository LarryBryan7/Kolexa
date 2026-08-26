// ============================================================
// Tests unitarios — AdminService.getSchoolSummary
// ============================================================
// Endpoint nuevo del dashboard del director (GET /admin/school/summary,
// ver plan de visibilidad del director). Prisma va mockeado a mano: valida
// la lógica de agregación (asistencia de hoy, pagos vencidos, docentes
// conectados a Classroom, último anuncio), no el aislamiento multi-tenant
// en sí — eso ya lo garantiza que schoolId siempre sale del JWT
// (@Roles('school_admin') + user.schoolId!, nunca del cliente).
// ============================================================

import { AdminService } from '../../src/modules/admin/admin.service';

function makePrisma(overrides: Record<string, any> = {}) {
  return {
    classroom: { count: jest.fn().mockResolvedValue(0) },
    student: { count: jest.fn().mockResolvedValue(0) },
    userRole: { count: jest.fn().mockResolvedValue(0) },
    attendance: { findMany: jest.fn().mockResolvedValue([]) },
    paymentObligation: {
      aggregate: jest.fn().mockResolvedValue({ _sum: { amount: null } }),
    },
    teacherGoogleToken: { count: jest.fn().mockResolvedValue(0) },
    announcement: { findFirst: jest.fn().mockResolvedValue(null) },
    ...overrides,
  };
}

describe('AdminService.getSchoolSummary', () => {
  const SCHOOL_A = 1n;

  it('calcula el % de asistencia de hoy ignorando ausentes y contando tardanzas/justificadas como presentes', async () => {
    const prisma = makePrisma({
      classroom: { count: jest.fn().mockResolvedValue(3) },
      attendance: {
        findMany: jest.fn().mockResolvedValue([
          {
            classroomId: 10n,
            records: [
              { status: 'present' },
              { status: 'late' },
              { status: 'absent' },
              { status: 'justified' },
            ],
          },
        ]),
      },
    });
    const service = new AdminService(prisma as any);

    const result = await service.getSchoolSummary(SCHOOL_A);

    expect(result.attendanceTodayPercent).toBe(75); // 3 de 4 no ausentes
    // Solo 1 de 3 aulas pasó lista hoy.
    expect(result.classroomsWithoutAttendanceToday).toBe(2);
  });

  it('attendanceTodayPercent es null cuando ningún aula pasó lista hoy (no 0 ni NaN)', async () => {
    const prisma = makePrisma();
    const service = new AdminService(prisma as any);

    const result = await service.getSchoolSummary(SCHOOL_A);

    expect(result.attendanceTodayPercent).toBeNull();
  });

  it('overduePaymentsTotal usa dueDate < hoy AND status NOT IN (paid, waived) — nunca status = overdue', async () => {
    const prisma = makePrisma({
      paymentObligation: {
        aggregate: jest.fn().mockResolvedValue({ _sum: { amount: '450.50' } }),
      },
    });
    const service = new AdminService(prisma as any);

    const result = await service.getSchoolSummary(SCHOOL_A);

    expect(prisma.paymentObligation.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          student: { schoolId: SCHOOL_A },
          status: { notIn: ['paid', 'waived'] },
        }),
      }),
    );
    expect(result.overduePaymentsTotal).toBe(450.5);
  });

  it('overduePaymentsTotal es 0 (no null) cuando no hay pagos vencidos', async () => {
    const service = new AdminService(makePrisma() as any);
    const result = await service.getSchoolSummary(SCHOOL_A);
    expect(result.overduePaymentsTotal).toBe(0);
  });

  it('teacherCount y teachersConnectedToClassroom se scopean al colegio y al rol teacher', async () => {
    const prisma = makePrisma({
      userRole: { count: jest.fn().mockResolvedValue(7) },
      teacherGoogleToken: { count: jest.fn().mockResolvedValue(4) },
    });
    const service = new AdminService(prisma as any);

    const result = await service.getSchoolSummary(SCHOOL_A);

    expect(prisma.userRole.count).toHaveBeenCalledWith({
      where: { schoolId: SCHOOL_A, role: { name: 'teacher' } },
    });
    expect(result.teacherCount).toBe(7);
    expect(result.teachersConnectedToClassroom).toBe(4);
  });

  it('latestAnnouncement es null cuando el colegio no tiene anuncios (sin inventar datos)', async () => {
    const service = new AdminService(makePrisma() as any);
    const result = await service.getSchoolSummary(SCHOOL_A);
    expect(result.latestAnnouncement).toBeNull();
  });

  it('latestAnnouncement devuelve título + fecha del anuncio más reciente del colegio', async () => {
    const createdAt = new Date('2026-08-20T10:00:00Z');
    const prisma = makePrisma({
      announcement: {
        findFirst: jest.fn().mockResolvedValue({ title: 'Reunión de padres', createdAt }),
      },
    });
    const service = new AdminService(prisma as any);

    const result = await service.getSchoolSummary(SCHOOL_A);

    expect(prisma.announcement.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { schoolId: SCHOOL_A } }),
    );
    expect(result.latestAnnouncement).toEqual({ title: 'Reunión de padres', createdAt });
  });
});
