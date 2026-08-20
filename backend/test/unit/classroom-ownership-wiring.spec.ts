// ============================================================
// Regresión BL-6 — ClassroomController: wiring del ownership gate
// ============================================================
// classroom.service.ts:assertStudentOwnedByParent() ya se prueba contra
// Postgres real en authorization-idor.integration.spec.ts. Este archivo
// prueba la otra mitad del hallazgo: que los 8 endpoints student/:id/* +
// parent/home + parent/today-summary REALMENTE llaman a ese guard ANTES
// de delegar al resto del service (que sigue intacto — no se tocó
// ninguna lógica de OAuth/sync, solo se antepuso la verificación).
// ============================================================

import { ForbiddenException } from '@nestjs/common';
import { ClassroomController } from '../../src/modules/classroom/classroom.controller';

const fakeUser: any = { sub: 10n, email: 'padre@x.com', roles: ['parent'], schoolId: 1n };
// bigint, no string: ParseBigIntPipe (hallazgo IM-3 extendido a este
// controller, Ronda 4) ya convirtió el @Param/@Query a bigint antes de
// que Nest llame al método — estos tests llaman al método directamente
// (sin pasar por el pipe real, que se prueba aparte en
// invitations-parentid-validation.spec.ts), así que deben pasar el
// mismo tipo que el pipe entregaría.
const STUDENT_A = 5n;
const STUDENT_B = 999n;

function makeService() {
  return {
    assertStudentOwnedByParent: jest.fn(async (_userId: bigint, studentId: bigint) => {
      if (studentId !== 5n) throw new ForbiddenException('No tienes acceso a este alumno');
    }),
    getAuthUrl: jest.fn().mockReturnValue('https://accounts.google.com/fake'),
    isConnected: jest.fn().mockResolvedValue(true),
    syncStudent: jest.fn().mockResolvedValue({ courses: 1, courseworks: 1, cacheHit: false }),
    getCourses: jest.fn().mockResolvedValue([]),
    getUpcomingCoursework: jest.fn().mockResolvedValue([]),
    getOverview: jest.fn().mockResolvedValue({ connected: true }),
    getUpcomingStatus: jest.fn().mockResolvedValue({ connected: true, upcoming: [] }),
    getParentHome: jest.fn().mockResolvedValue({ todaySummary: {}, upcomingStatus: {} }),
    getParentTodaySummary: jest.fn().mockResolvedValue({ arrivalStatus: null }),
  };
}

describe('ClassroomController — ownership gate en los 8 endpoints student/:id/* + parent/*', () => {
  const cases: [string, (c: ClassroomController) => Promise<any>][] = [
    ['getAuthUrl', (c) => c.getAuthUrl(STUDENT_B, fakeUser)],
    ['getStatus', (c) => c.getStatus(STUDENT_B, fakeUser)],
    ['sync', (c) => c.sync(STUDENT_B, fakeUser)],
    ['getCourses', (c) => c.getCourses(STUDENT_B, fakeUser)],
    ['getUpcoming', (c) => c.getUpcoming(STUDENT_B, fakeUser)],
    ['getOverview', (c) => c.getOverview(STUDENT_B, fakeUser)],
    ['getUpcomingStatus', (c) => c.getUpcomingStatus(STUDENT_B, fakeUser)],
    ['getParentHome', (c) => c.getParentHome(STUDENT_B, fakeUser)],
    ['getParentTodaySummary', (c) => c.getParentTodaySummary(STUDENT_B, fakeUser)],
  ];

  it.each(cases)(
    'Parent A → Student B (ajeno) en %s → 403, y el método del service NUNCA se invoca',
    async (name, call) => {
      const service = makeService();
      const controller = new ClassroomController(service as any);

      await expect(call(controller)).rejects.toMatchObject({ status: 403 });

      expect(service.assertStudentOwnedByParent).toHaveBeenCalledWith(fakeUser.sub, 999n);
      // El método real del service (sync/getOverview/etc.) no debe haberse
      // llamado — el guard debe cortar ANTES, no después.
      const serviceMethodName = name === 'getParentTodaySummary' || name === 'getParentHome'
        ? name
        : name === 'getAuthUrl' ? 'getAuthUrl'
        : name === 'getStatus' ? 'isConnected'
        : name === 'sync' ? 'syncStudent'
        : name === 'getUpcoming' ? 'getUpcomingCoursework'
        : name;
      expect((service as any)[serviceMethodName]).not.toHaveBeenCalled();
    },
  );

  const legitimateCases: [string, (c: ClassroomController) => Promise<any>][] = [
    ['getStatus', (c) => c.getStatus(STUDENT_A, fakeUser)],
    ['sync', (c) => c.sync(STUDENT_A, fakeUser)],
    ['getCourses', (c) => c.getCourses(STUDENT_A, fakeUser)],
    ['getUpcoming', (c) => c.getUpcoming(STUDENT_A, fakeUser)],
    ['getOverview', (c) => c.getOverview(STUDENT_A, fakeUser)],
    ['getUpcomingStatus', (c) => c.getUpcomingStatus(STUDENT_A, fakeUser)],
    ['getParentHome', (c) => c.getParentHome(STUDENT_A, fakeUser)],
    ['getParentTodaySummary', (c) => c.getParentTodaySummary(STUDENT_A, fakeUser)],
  ];

  it.each(legitimateCases)(
    'Parent A → Student A (propio) en %s → sigue funcionando (no se rompió el caso legítimo)',
    async (_name, call) => {
      const service = makeService();
      const controller = new ClassroomController(service as any);

      await expect(call(controller)).resolves.toBeDefined();
      expect(service.assertStudentOwnedByParent).toHaveBeenCalledWith(fakeUser.sub, 5n);
    },
  );
});
