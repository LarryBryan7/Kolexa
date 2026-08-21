// ============================================================
// Regresión B-2 (auditoría 2026-08-19) — IDOR entre colegios en
// InvitationsService.findActiveForParent(). Postgres real (BD local).
// ============================================================
// Antes del fix, el método filtraba solo por parentId — cualquier
// school_admin autenticado, de CUALQUIER colegio, podía leer el token
// (y el email) de la invitación activa de un padre de OTRO colegio con
// solo adivinar/iterar su parentId. El fix exige que el Parent pertenezca
// al schoolId del admin autenticado (mismo patrón que
// AdminService.getParentOwned()).
// ============================================================

import { Test } from '@nestjs/testing';
import { InvitationsService } from '../../src/modules/invitations/invitations.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { assertLocalTestDatabase } from '../helpers/db-guard';

assertLocalTestDatabase();

describe('InvitationsService.findActiveForParent — aislamiento entre colegios (B-2)', () => {
  let prisma: PrismaService;
  let invitationsService: InvitationsService;
  let schoolA: bigint;
  let schoolB: bigint;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [InvitationsService, PrismaService],
    }).compile();
    prisma = moduleRef.get(PrismaService);
    invitationsService = moduleRef.get(InvitationsService);
    await prisma.$connect();

    const [a, b] = await Promise.all([
      prisma.school.create({ data: { name: `IDOR Test A ${Date.now()}`, isActive: true } }),
      prisma.school.create({ data: { name: `IDOR Test B ${Date.now()}`, isActive: true } }),
    ]);
    schoolA = a.id;
    schoolB = b.id;
  });

  afterAll(async () => {
    await prisma.schoolInvitation.deleteMany({ where: { schoolId: { in: [schoolA, schoolB] } } });
    await prisma.parent.deleteMany({ where: { schoolId: { in: [schoolA, schoolB] } } });
    await prisma.school.deleteMany({ where: { id: { in: [schoolA, schoolB] } } });
    await prisma.$disconnect();
  });

  it('un admin del colegio A no puede leer la invitación activa de un padre del colegio B', async () => {
    const parentB = await prisma.parent.create({
      data: {
        schoolId: schoolB, firstName: 'Padre', lastName: 'ColegioB',
        dni: 'IDOR-001', email: 'padre-b@idor-test.kolexa',
      },
    });
    await invitationsService.create(
      { schoolId: schoolB, email: parentB.email!, parentId: parentB.id },
      1n,
    );

    // El admin autenticado es del colegio A (schoolA), pero pide el
    // parentId de un padre que pertenece al colegio B.
    await expect(
      invitationsService.findActiveForParent(schoolA, parentB.id),
    ).rejects.toMatchObject({ status: 404 });
  });

  it('un admin del colegio dueño del padre SÍ puede leer su invitación activa', async () => {
    const parentA = await prisma.parent.create({
      data: {
        schoolId: schoolA, firstName: 'Padre', lastName: 'ColegioA',
        dni: 'IDOR-002', email: 'padre-a@idor-test.kolexa',
      },
    });
    const created = await invitationsService.create(
      { schoolId: schoolA, email: parentA.email!, parentId: parentA.id },
      1n,
    );

    const found = await invitationsService.findActiveForParent(schoolA, parentA.id);
    expect(found?.token).toBe(created.token);
  });

  it('parentId inexistente devuelve 404, no una lista vacía silenciosa', async () => {
    await expect(
      invitationsService.findActiveForParent(schoolA, 999999999n),
    ).rejects.toMatchObject({ status: 404 });
  });
});
