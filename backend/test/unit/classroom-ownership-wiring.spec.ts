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
    // assertStudentReadAccess: mismo guard que assertStudentOwnedByParent,
    // pero usado por los endpoints de LECTURA (agrega bypass para
    // school_admin — no ejercitado en este archivo, ver
    // director-read-access.spec.ts). fakeUser es 'parent', así que el
    // comportamiento observable acá es idéntico al de arriba.
    assertStudentReadAccess: jest.fn(async (_user: any, studentId: bigint) => {
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
    uploadStudentAvatar: jest.fn().mockResolvedValue({ avatarUrl: 'https://signed.example/fake.jpg' }),
  };
}

const fakeFile: any = { originalname: 'foto.jpg', mimetype: 'image/jpeg', buffer: Buffer.from('x') };

// Endpoints de escritura/acción: siguen usando assertStudentOwnedByParent
// (sin bypass de school_admin — ver plan de visibilidad del director).
const WRITE_ENDPOINTS = new Set(['getAuthUrl', 'sync', 'uploadAvatar']);
function guardMockFor(service: ReturnType<typeof makeService>, name: string) {
  return WRITE_ENDPOINTS.has(name) ? service.assertStudentOwnedByParent : service.assertStudentReadAccess;
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
    ['uploadAvatar', (c) => c.uploadAvatar(STUDENT_B, fakeFile, fakeUser)],
  ];

  it.each(cases)(
    'Parent A → Student B (ajeno) en %s → 403, y el método del service NUNCA se invoca',
    async (name, call) => {
      const service = makeService();
      const controller = new ClassroomController(service as any);

      await expect(call(controller)).rejects.toMatchObject({ status: 403 });

      const guardMock = guardMockFor(service, name);
      const expectedFirstArg = WRITE_ENDPOINTS.has(name) ? fakeUser.sub : fakeUser;
      expect(guardMock).toHaveBeenCalledWith(expectedFirstArg, 999n);
      // El método real del service (sync/getOverview/etc.) no debe haberse
      // llamado — el guard debe cortar ANTES, no después.
      const serviceMethodName = name === 'getParentTodaySummary' || name === 'getParentHome'
        ? name
        : name === 'getAuthUrl' ? 'getAuthUrl'
        : name === 'getStatus' ? 'isConnected'
        : name === 'sync' ? 'syncStudent'
        : name === 'getUpcoming' ? 'getUpcomingCoursework'
        : name === 'uploadAvatar' ? 'uploadStudentAvatar'
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
    ['uploadAvatar', (c) => c.uploadAvatar(STUDENT_A, fakeFile, fakeUser)],
  ];

  it.each(legitimateCases)(
    'Parent A → Student A (propio) en %s → sigue funcionando (no se rompió el caso legítimo)',
    async (name, call) => {
      const service = makeService();
      const controller = new ClassroomController(service as any);

      await expect(call(controller)).resolves.toBeDefined();
      const guardMock = guardMockFor(service, name);
      const expectedFirstArg = WRITE_ENDPOINTS.has(name) ? fakeUser.sub : fakeUser;
      expect(guardMock).toHaveBeenCalledWith(expectedFirstArg, 5n);
    },
  );
});
