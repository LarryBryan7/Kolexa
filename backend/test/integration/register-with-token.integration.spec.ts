// ============================================================
// Regresión — registerWithToken(): fix de la race condition +
// bloqueo explícito de invitaciones de tipo Parent en este flujo.
// Postgres real (BD de test local).
// ============================================================

import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { AuthService } from '../../src/modules/auth/auth.service';
import { SupabaseStorageService } from '../../src/modules/storage/supabase-storage.service';
import { InvitationsService } from '../../src/modules/invitations/invitations.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { assertLocalTestDatabase } from '../helpers/db-guard';

assertLocalTestDatabase();

describe('registerWithToken — consumo de invitación (regresión de concurrencia)', () => {
  let prisma: PrismaService;
  let authService: AuthService;
  let invitationsService: InvitationsService;
  let schoolId: bigint;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService, InvitationsService, PrismaService, SupabaseStorageService,
        { provide: JwtService, useValue: { sign: jest.fn().mockReturnValue('jwt.fake') } },
        { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue('fake-client-id') } },
      ],
    }).compile();
    prisma = moduleRef.get(PrismaService);
    authService = moduleRef.get(AuthService);
    invitationsService = moduleRef.get(InvitationsService);
    await prisma.$connect();
    const school = await prisma.school.create({ data: { name: `RWT Test ${Date.now()}`, isActive: true } });
    schoolId = school.id;
  });

  afterAll(async () => {
    const users = await prisma.user.findMany({ where: { email: { contains: '@rwt-test.kolexa' } }, select: { id: true } });
    const ids = users.map((u) => u.id);
    await prisma.userToken.deleteMany({ where: { userId: { in: ids } } });
    await prisma.userRole.deleteMany({ where: { userId: { in: ids } } });
    await prisma.schoolInvitation.deleteMany({ where: { schoolId } });
    await prisma.user.deleteMany({ where: { id: { in: ids } } });
    await prisma.school.delete({ where: { id: schoolId } });
    await prisma.$disconnect();
  });

  it('flujo feliz sigue funcionando tras el fix (docente, invitación genérica)', async () => {
    const email = 'docente@rwt-test.kolexa';
    const inv = await invitationsService.create({ schoolId, email, role: 'teacher' }, 1n);

    const result = await authService.registerWithToken({
      token: inv.token, password: 'Segura123', firstName: 'Doc', lastName: 'Ente',
    } as any);
    expect(result.accessToken).toBeDefined();

    const invAfter = await prisma.schoolInvitation.findUnique({ where: { token: inv.token } });
    expect(invAfter!.usedAt).not.toBeNull();
  });

  it('10 peticiones concurrentes con el MISMO token genérico: 1 éxito, 9 rechazos, sin corrupción', async () => {
    const email = 'concurrente@rwt-test.kolexa';
    const inv = await invitationsService.create({ schoolId, email, role: 'teacher' }, 1n);

    const results = await Promise.allSettled(
      Array.from({ length: 10 }, (_, i) =>
        authService.registerWithToken({
          token: inv.token, password: 'Segura123', firstName: `Doc${i}`, lastName: 'Ente',
        } as any),
      ),
    );

    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');
    expect(fulfilled.length).toBe(1);
    expect(rejected.length).toBe(9);

    const usersCreated = await prisma.user.count({ where: { email } });
    expect(usersCreated).toBe(1); // ninguna carrera duplicó el User

    const invAfter = await prisma.schoolInvitation.findUnique({ where: { token: inv.token } });
    expect(invAfter!.usedAt).not.toBeNull();
  });

  it('rechaza una invitación de tipo Parent — debe usarse Google Sign-In, no este flujo', async () => {
    const parent = await prisma.parent.create({
      data: { schoolId, firstName: 'Padre', lastName: 'RWT', dni: 'RWT-001', email: 'padre@rwt-test.kolexa' },
    });
    const inv = await invitationsService.create(
      { schoolId, email: parent.email!, parentId: parent.id },
      1n,
    );

    await expect(
      authService.registerWithToken({
        token: inv.token, password: 'Segura123', firstName: 'Padre', lastName: 'RWT',
      } as any),
    ).rejects.toThrow('Esta invitación requiere iniciar sesión con Google');

    // Nada se tocó: el Parent sigue sin vincular, la invitación sigue sin usar.
    const parentAfter = await prisma.parent.findUnique({ where: { id: parent.id } });
    expect(parentAfter!.userId).toBeNull();
    const invAfter = await prisma.schoolInvitation.findUnique({ where: { token: inv.token } });
    expect(invAfter!.usedAt).toBeNull();

    await prisma.schoolInvitation.deleteMany({ where: { id: BigInt((await prisma.schoolInvitation.findUnique({ where: { token: inv.token } }))!.id) } });
    await prisma.parent.delete({ where: { id: parent.id } });
  });
});
