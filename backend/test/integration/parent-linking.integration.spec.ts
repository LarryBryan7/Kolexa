// ============================================================
// Tests de integración — vinculación de padres, Postgres REAL
// ============================================================
// Requiere DATABASE_URL apuntando a una BD de TEST/DEV controlada
// (nunca DEV Supabase compartida, nunca PROD). Por defecto usa el
// Postgres local (kolexa_dev) — ver test/README.md.
//
// Solo OAuth2Client.verifyIdToken() va mockeado (no se puede llamar a
// Google real en tests). Todo lo demás — Prisma, transacciones,
// constraints de Postgres — es real.
// ============================================================

import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';
import { AuthService } from '../../src/modules/auth/auth.service';
import { InvitationsService } from '../../src/modules/invitations/invitations.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { assertLocalTestDatabase } from '../helpers/db-guard';

assertLocalTestDatabase();

const mockVerifyIdToken = jest.fn();
jest.mock('google-auth-library', () => ({
  OAuth2Client: jest.fn().mockImplementation(() => ({ verifyIdToken: mockVerifyIdToken })),
}));

const googlePayload = (email: string, sub: string, emailVerified = true) => ({
  sub, email, email_verified: emailVerified, given_name: 'Test', family_name: 'Parent', picture: null,
});

describe('Vinculación de padres — integración con Postgres real', () => {
  let prisma: PrismaService;
  let authService: AuthService;
  let invitationsService: InvitationsService;
  let schoolId: bigint;
  const PARENT_ROLE_ID = 3; // ya confirmado por consulta directa en kolexa_dev

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        InvitationsService,
        PrismaService,
        { provide: JwtService, useValue: { sign: jest.fn().mockReturnValue('jwt.fake') } },
        { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue('fake-client-id') } },
      ],
    }).compile();

    prisma = moduleRef.get(PrismaService);
    authService = moduleRef.get(AuthService);
    invitationsService = moduleRef.get(InvitationsService);
    await prisma.$connect();

    const school = await prisma.school.create({
      data: { name: `Test School ${Date.now()}`, isActive: true },
    });
    schoolId = school.id;
  });

  afterAll(async () => {
    // Limpieza en orden por FKs (user_tokens/push_tokens con RESTRICT hacia
    // users, hay que borrarlos antes que el propio User).
    const testUsers = await prisma.user.findMany({
      where: { email: { contains: '@integration-test.kolexa' } },
      select: { id: true },
    });
    const testUserIds = testUsers.map((u) => u.id);
    await prisma.userToken.deleteMany({ where: { userId: { in: testUserIds } } });
    await prisma.pushToken.deleteMany({ where: { userId: { in: testUserIds } } });
    // userStudent (puente B-1): si algún test falló antes de su cleanup
    // inline, estas filas bloquearían el delete de User más abajo (FK).
    await prisma.userStudent.deleteMany({ where: { userId: { in: testUserIds } } });
    await prisma.userRole.deleteMany({ where: { userId: { in: testUserIds } } });
    await prisma.schoolInvitation.deleteMany({ where: { schoolId } });
    await prisma.parent.deleteMany({ where: { schoolId } });
    // Alumnos de test creados directamente bajo este schoolId (cleanup por
    // si algún test de B-1 falló antes de su borrado inline).
    await prisma.student.deleteMany({ where: { schoolId, code: { contains: 'B1-STU-' } } });
    await prisma.user.deleteMany({ where: { id: { in: testUserIds } } });
    await prisma.school.delete({ where: { id: schoolId } });
    await prisma.$disconnect();
  });

  beforeEach(() => {
    mockVerifyIdToken.mockReset();
  });

  async function makeParent(dni: string) {
    return prisma.parent.create({
      data: { schoolId, firstName: 'Padre', lastName: 'Integración', dni, email: `${dni}@integration-test.kolexa` },
    });
  }

  async function makeInvitation(parentId: bigint, email: string) {
    const inv = await invitationsService.create(
      { schoolId, email, roleId: PARENT_ROLE_ID, parentId },
      1n,
    );
    return inv.token;
  }

  it('flujo feliz completo: crea User nuevo, UserRole, vincula Parent, consume invitación', async () => {
    const parent = await makeParent('IT-001');
    const email = parent.email!;
    const sub = crypto.randomUUID();
    const token = await makeInvitation(parent.id, email);

    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(email, sub) });

    const result = await authService.loginWithGoogle({ idToken: 'x', invitationToken: token } as any);
    expect(result.accessToken).toBe('jwt.fake');

    const updatedParent = await prisma.parent.findUnique({ where: { id: parent.id } });
    expect(updatedParent!.userId).not.toBeNull();
    expect(updatedParent!.linkStatus).toBe('linked');

    const invitation = await prisma.schoolInvitation.findUnique({ where: { token } });
    expect(invitation!.usedAt).not.toBeNull();

    const userRole = await prisma.userRole.findFirst({
      where: { userId: updatedParent!.userId!, roleId: PARENT_ROLE_ID, schoolId },
    });
    expect(userRole).not.toBeNull();
  });

  it('User existente + nueva invitación para OTRO Parent: reutiliza User, agrega vínculo nuevo', async () => {
    const sub = crypto.randomUUID();
    const parentA = await makeParent('IT-002A');
    const parentB = await makeParent('IT-002B');
    const emailA = parentA.email!;

    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(emailA, sub) });
    const tokenA = await makeInvitation(parentA.id, emailA);
    await authService.loginWithGoogle({ idToken: 'x', invitationToken: tokenA } as any);

    const linkedA = await prisma.parent.findUnique({ where: { id: parentA.id } });
    const userId = linkedA!.userId!;

    // Segunda invitación, mismo User (mismo googleSub), OTRO Parent, mismo colegio.
    const emailB = parentB.email!;
    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(emailB, sub) });
    const tokenB = await makeInvitation(parentB.id, emailB);
    await authService.loginWithGoogle({ idToken: 'x', invitationToken: tokenB } as any);

    const linkedB = await prisma.parent.findUnique({ where: { id: parentB.id } });
    expect(linkedB!.userId).toBe(userId); // mismo User

    const userCount = await prisma.user.count({ where: { id: userId } });
    expect(userCount).toBe(1); // no se duplicó el User
  });

  it('User existente + invitación para OTRO colegio: crea un segundo UserRole (multi-colegio)', async () => {
    const sub = crypto.randomUUID();
    const parent1 = await makeParent('IT-003A');
    const email = parent1.email!;

    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(email, sub) });
    const token1 = await makeInvitation(parent1.id, email);
    await authService.loginWithGoogle({ idToken: 'x', invitationToken: token1 } as any);
    const linked1 = await prisma.parent.findUnique({ where: { id: parent1.id } });
    const userId = linked1!.userId!;

    // Segundo colegio.
    const school2 = await prisma.school.create({ data: { name: `Test School 2 ${Date.now()}`, isActive: true } });
    const parent2 = await prisma.parent.create({
      data: { schoolId: school2.id, firstName: 'Padre', lastName: 'Colegio2', dni: 'IT-003B', email },
    });
    const inv2 = await invitationsService.create(
      { schoolId: school2.id, email, roleId: PARENT_ROLE_ID, parentId: parent2.id },
      1n,
    );
    await authService.loginWithGoogle({ idToken: 'x', invitationToken: inv2.token } as any);

    const roles = await prisma.userRole.findMany({ where: { userId } });
    const schoolIds = roles.map((r) => r.schoolId?.toString());
    expect(schoolIds).toEqual(expect.arrayContaining([schoolId.toString(), school2.id.toString()]));

    // Limpieza específica de este test (segundo colegio no está en afterAll).
    await prisma.userRole.deleteMany({ where: { schoolId: school2.id } });
    await prisma.schoolInvitation.deleteMany({ where: { schoolId: school2.id } });
    await prisma.parent.deleteMany({ where: { schoolId: school2.id } });
    await prisma.school.delete({ where: { id: school2.id } });
  });

  it('Parent ya vinculado a OTRO User: rechaza con INVITATION_ALREADY_USED, sin tocar nada', async () => {
    const parent = await makeParent('IT-004');
    const email = parent.email!;
    const subA = crypto.randomUUID();
    const subB = crypto.randomUUID();

    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(email, subA) });
    const token = await makeInvitation(parent.id, email);
    await authService.loginWithGoogle({ idToken: 'x', invitationToken: token } as any);

    // Segundo intento, MISMO token ya usado, OTRA cuenta Google (no debería
    // pasar en la práctica porque el email debe coincidir con el de la
    // invitación, pero probamos el peor caso: alguien reutiliza un token ya
    // consumido).
    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(email, subB) });
    await expect(
      authService.loginWithGoogle({ idToken: 'x', invitationToken: token } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_ALREADY_USED' });

    const userB = await prisma.user.findUnique({ where: { googleSub: subB } });
    expect(userB).toBeNull(); // el segundo User NUNCA se creó
  });

  it('Parent ya vinculado al MISMO User (retry secuencial): idempotente, no falla', async () => {
    const parent = await makeParent('IT-005');
    const email = parent.email!;
    const sub = crypto.randomUUID();

    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(email, sub) });
    const token = await makeInvitation(parent.id, email);
    const first = await authService.loginWithGoogle({ idToken: 'x', invitationToken: token } as any);

    // Reintento con el MISMO token, MISMA cuenta Google (ej. doble-tap con
    // la petición anterior ya confirmada en servidor).
    const second = await authService.loginWithGoogle({ idToken: 'x', invitationToken: token } as any);
    expect(second.user.id).toBe(first.user.id);

    const linked = await prisma.parent.findUnique({ where: { id: parent.id } });
    expect(linked!.userId!.toString()).toBe(first.user.id);
  });

  it('invitación reutilizada tras expirar la vigencia no puede reclamarse por un User nuevo', async () => {
    const parent = await makeParent('IT-006');
    const email = parent.email!;
    const inv = await invitationsService.create(
      { schoolId, email, roleId: PARENT_ROLE_ID, parentId: parent.id },
      1n,
    );
    // Forzamos expiración directa en BD (sin esperar 7 días reales).
    await prisma.schoolInvitation.update({ where: { id: BigInt((await prisma.schoolInvitation.findUnique({ where: { token: inv.token } }))!.id) }, data: { expiresAt: new Date(Date.now() - 1000) } });

    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(email, crypto.randomUUID()) });
    await expect(
      authService.loginWithGoogle({ idToken: 'x', invitationToken: inv.token } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_EXPIRED' });
  });

  // ── B-3 (auditoría 2026-08-19): email_verified de Google ──────────────
  it('B-3 — rechaza con INVITATION_EMAIL_MISMATCH si el ID Token trae email_verified: false, sin crear nada', async () => {
    const parent = await makeParent('IT-007');
    const email = parent.email!;
    const sub = crypto.randomUUID();
    const token = await makeInvitation(parent.id, email);

    // Mismo email exacto de la invitación, pero Google marca el correo
    // como no verificado — el diseño original solo comparaba el email de
    // texto, sin exigir que Google lo respalde como verificado.
    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(email, sub, false) });

    await expect(
      authService.loginWithGoogle({ idToken: 'x', invitationToken: token } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_EMAIL_MISMATCH' });

    const untouchedParent = await prisma.parent.findUnique({ where: { id: parent.id } });
    expect(untouchedParent!.userId).toBeNull();
    expect(untouchedParent!.linkStatus).toBe('pending');

    const untouchedInv = await prisma.schoolInvitation.findUnique({ where: { token } });
    expect(untouchedInv!.usedAt).toBeNull();

    const createdUser = await prisma.user.findUnique({ where: { googleSub: sub } });
    expect(createdUser).toBeNull();
  });

  // ── B-1 (auditoría 2026-08-19): puente ParentStudent → UserStudent ────
  it('B-1 — al vincular, replica en UserStudent los hijos ya asignados al Parent institucional', async () => {
    const parent = await makeParent('IT-008');
    const email = parent.email!;
    const sub = crypto.randomUUID();

    const student = await prisma.student.create({
      data: { schoolId, firstName: 'Hijo', lastName: 'DePrueba', code: `B1-STU-${Date.now().toString(36)}` },
    });
    await prisma.parentStudent.create({
      data: { parentId: parent.id, studentId: student.id, relationship: 'padre', isPrimary: true },
    });

    const token = await makeInvitation(parent.id, email);
    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(email, sub) });

    const result = await authService.loginWithGoogle({ idToken: 'x', invitationToken: token } as any);
    const userId = BigInt(result.user.id);

    const bridged = await prisma.userStudent.findFirst({
      where: { userId, studentId: student.id },
    });
    expect(bridged).not.toBeNull();
    expect(bridged!.relationship).toBe('padre');
    expect(bridged!.isPrimary).toBe(true);

    // El login devuelve la misma lista de hijos que ve un padre por
    // email/password — antes de este fix, `children` quedaba vacío pese a
    // que el Parent institucional sí tenía al hijo asignado.
    expect(result.user.children.map((c: any) => c.id)).toContain(student.id.toString());

    await prisma.userStudent.deleteMany({ where: { userId, studentId: student.id } });
    await prisma.parentStudent.deleteMany({ where: { parentId: parent.id, studentId: student.id } });
    await prisma.student.delete({ where: { id: student.id } });
  });

  // ── B-1 (admin.service.ts): puente al agregar un hijo DESPUÉS de vincular ─
  it('B-1 — AdminService.createParentStudentLink bridgea a UserStudent si el Parent ya estaba vinculado', async () => {
    const { AdminService } = await import('../../src/modules/admin/admin.service');
    const moduleRef = await Test.createTestingModule({
      providers: [AdminService, PrismaService],
    }).compile();
    const adminService = moduleRef.get(AdminService);

    const parent = await makeParent('IT-009');
    const email = parent.email!;
    const sub = crypto.randomUUID();
    const token = await makeInvitation(parent.id, email);
    mockVerifyIdToken.mockResolvedValue({ getPayload: () => googlePayload(email, sub) });
    const result = await authService.loginWithGoogle({ idToken: 'x', invitationToken: token } as any);
    const userId = BigInt(result.user.id);

    const student = await prisma.student.create({
      data: { schoolId, firstName: 'Hijo', lastName: 'Posterior', code: `B1-STU-${Date.now().toString(36)}` },
    });

    // El colegio asigna el hijo DESPUÉS de que el padre ya vinculó su
    // cuenta (Parent.userId ya no es null en este punto) — sin el puente
    // en createParentStudentLink, el padre no vería a este hijo hasta un
    // mecanismo aparte que no existe.
    await adminService.createParentStudentLink(schoolId, {
      parentId: Number(parent.id), studentId: Number(student.id), relationship: 'padre', isPrimary: false,
    } as any);

    const bridged = await prisma.userStudent.findFirst({ where: { userId, studentId: student.id } });
    expect(bridged).not.toBeNull();

    await prisma.userStudent.deleteMany({ where: { userId, studentId: student.id } });
    await prisma.parentStudent.deleteMany({ where: { parentId: parent.id, studentId: student.id } });
    await prisma.student.delete({ where: { id: student.id } });
  });
});
