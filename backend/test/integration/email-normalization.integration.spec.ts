// ============================================================
// Regresión IM-7 (Ronda 4) — normalización consistente de email
// ============================================================
// Antes: solo loginWithGoogle() normalizaba (trim+lowercase), y solo
// para la comparación en memoria — nunca antes de guardar. createUser,
// createParent, updateParent, invitations.create y login() guardaban/
// comparaban el email tal cual llegaba. Fix: @NormalizeEmail() (un único
// @Transform reusado) en los 5 DTOs correspondientes — se prueba tanto a
// nivel DTO (unitario) como el efecto real en BD (integración).
// ============================================================

import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { Test } from '@nestjs/testing';
import { ConflictException } from '@nestjs/common';
import { LoginDto } from '../../src/modules/auth/dto/login.dto';
import { CreateUserDto } from '../../src/modules/admin/dto/create-user.dto';
import { CreateParentDto } from '../../src/modules/admin/dto/create-parent.dto';
import { UpdateParentDto } from '../../src/modules/admin/dto/update-parent.dto';
import { CreateInvitationDto } from '../../src/modules/invitations/dto/create-invitation.dto';
import { AdminService } from '../../src/modules/admin/admin.service';
import { InvitationsService } from '../../src/modules/invitations/invitations.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { assertLocalTestDatabase } from '../helpers/db-guard';

assertLocalTestDatabase();

const RAW = '  Padre@Example.COM  ';
const NORMALIZED = 'padre@example.com';

describe('@NormalizeEmail() — a nivel de DTO (unitario, los 5 DTOs)', () => {
  it.each([
    ['LoginDto', LoginDto, { email: RAW, password: '123456' }],
    ['CreateUserDto', CreateUserDto, { email: RAW, firstName: 'X', role: 'teacher' }],
    ['CreateParentDto', CreateParentDto, { email: RAW, firstName: 'X' }],
    ['UpdateParentDto', UpdateParentDto, { email: RAW }],
    ['CreateInvitationDto', CreateInvitationDto, { email: RAW }],
  ])('%s — "%s" se normaliza a "padre@example.com"', async (_name, Dto, plain) => {
    const dto = plainToInstance(Dto as any, plain) as any;
    expect(dto.email).toBe(NORMALIZED);
    const errors = await validate(dto);
    expect(errors.find((e: any) => e.property === 'email')).toBeUndefined();
  });

  it('un email con formato inválido sigue siendo rechazado después de normalizar', async () => {
    const dto = plainToInstance(LoginDto, { email: '  no-es-un-email  ', password: '123456' });
    const errors = await validate(dto);
    expect(errors.find((e) => e.property === 'email')).toBeDefined();
  });
});

describe('IM-7 — efecto real en BD: sin duplicados por capitalización (Postgres real)', () => {
  let prisma: PrismaService;
  let adminService: AdminService;
  let invitationsService: InvitationsService;
  let schoolId: bigint;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [AdminService, InvitationsService, PrismaService],
    }).compile();
    prisma = moduleRef.get(PrismaService);
    adminService = moduleRef.get(AdminService);
    invitationsService = moduleRef.get(InvitationsService);
    await prisma.$connect();

    const school = await prisma.school.create({ data: { name: `IM7-Norm ${Date.now()}`, isActive: true } });
    schoolId = school.id;
  });

  afterAll(async () => {
    const users = await prisma.user.findMany({ where: { email: { contains: '@im7-test.kolexa' } }, select: { id: true } });
    const ids = users.map((u) => u.id);
    await prisma.userRole.deleteMany({ where: { userId: { in: ids } } });
    await prisma.schoolInvitation.deleteMany({ where: { schoolId } });
    await prisma.parent.deleteMany({ where: { schoolId } });
    await prisma.user.deleteMany({ where: { id: { in: ids } } });
    await prisma.school.delete({ where: { id: schoolId } });
    await prisma.$disconnect();
  });

  it('createUser con "Docente@im7-test.kolexa" y luego "docente@IM7-TEST.kolexa" (mismo rol/colegio) reconoce al MISMO usuario, no crea un duplicado', async () => {
    const email = `Docente-${Date.now()}@im7-test.kolexa`;
    const dto1 = plainToInstance(CreateUserDto, { email, firstName: 'Docente', role: 'teacher' });
    await adminService.createUser(schoolId, dto1);

    const usersAfterFirst = await prisma.user.count({ where: { email: email.toLowerCase() } });
    expect(usersAfterFirst).toBe(1);

    // Mismo email, distinta capitalización, MISMO rol/colegio → debe
    // reconocer al usuario ya creado y rechazar por rol duplicado, NUNCA
    // crear un segundo User.
    const dto2 = plainToInstance(CreateUserDto, { email: email.toUpperCase(), firstName: 'Docente', role: 'teacher' });
    await expect(adminService.createUser(schoolId, dto2)).rejects.toBeInstanceOf(ConflictException);

    const totalUsers = await prisma.user.count({ where: { email: email.toLowerCase() } });
    expect(totalUsers).toBe(1); // sigue siendo uno solo — no se duplicó
  });

  it('invitación creada con email en mayúsculas se guarda normalizada en BD', async () => {
    const parent = await prisma.parent.create({
      data: { schoolId, firstName: 'Padre', lastName: 'IM7', dni: `IM7-${Date.now()}`, email: `padre-${Date.now()}@im7-test.kolexa` },
    });
    const email = `Padre-${Date.now()}@IM7-TEST.kolexa`;
    const dto = plainToInstance(CreateInvitationDto, { email, parentId: String(parent.id) });

    const created = await invitationsService.create(
      { schoolId, email: dto.email, parentId: parent.id },
      1n,
    );

    const stored = await prisma.schoolInvitation.findUnique({ where: { token: created.token } });
    expect(stored!.email).toBe(email.trim().toLowerCase());
    expect(stored!.email).not.toBe(email); // confirma que NO se guardó tal cual
  });
});
