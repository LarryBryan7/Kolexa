// ============================================================
// Tests unitarios — AuthService.loginWithGoogle (flujo de Parent)
// ============================================================
// Prisma y OAuth2Client van mockeados: valida la lógica de
// validación/branching de loginWithGoogle sin tocar ninguna base de
// datos real. Los tests de integración/concurrencia (test/integration,
// test/concurrency) sí usan Postgres real, contra la BD de test local.
// ============================================================

import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import {
  UnauthorizedException,
  NotFoundException,
  BadRequestException,
  ConflictException,
} from '@nestjs/common';
import { AuthService } from '../../src/modules/auth/auth.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { SupabaseStorageService } from '../../src/modules/storage/supabase-storage.service';

// google-auth-library mockeado a nivel de módulo — así no se toca la
// validación criptográfica real, solo se controla su resultado en cada test.
const mockVerifyIdToken = jest.fn();
jest.mock('google-auth-library', () => ({
  OAuth2Client: jest.fn().mockImplementation(() => ({
    verifyIdToken: mockVerifyIdToken,
  })),
}));

// bcrypt real es lento a propósito (factor de costo 10) — se mockea para
// no pagar ese costo en cada test, y de paso registrar EN QUÉ ORDEN se
// invoca respecto a prisma.$transaction (ver mockCallOrder más abajo),
// que es exactamente lo que el test de I-2 necesita verificar. El nombre
// "mockCallOrder" está prefijado con "mock" a propósito: es la única forma
// que permite Jest de referenciar una variable de fuera del scope del
// factory de jest.mock (hoisting).
const mockCallOrder: string[] = [];
jest.mock('bcrypt', () => ({
  hash: jest.fn(async () => {
    mockCallOrder.push('bcrypt.hash');
    return 'hashed-random-password';
  }),
  compare: jest.fn(),
}));

describe('AuthService.loginWithGoogle — flujo de Parent con invitación', () => {
  let service: AuthService;
  let prisma: any;

  const PARENT_ROLE_ID = 4;
  const SCHOOL_ID = 1n;
  const PARENT_ID = 10n;
  const INVITATION_ID = 100n;
  const GOOGLE_SUB = '118302549471462659437';
  const GOOGLE_EMAIL = 'padre@gmail.com';

  const validPayload = {
    sub: GOOGLE_SUB,
    email: GOOGLE_EMAIL,
    email_verified: true,
    given_name: 'Padre',
    family_name: 'De Prueba',
    picture: null,
  };

  const validInvitation = {
    id: INVITATION_ID,
    schoolId: SCHOOL_ID,
    email: GOOGLE_EMAIL,
    roleId: PARENT_ROLE_ID,
    token: 'tok_valido',
    parentId: PARENT_ID,
    invitedBy: 1n,
    usedAt: null,
    expiresAt: new Date(Date.now() + 1000 * 60 * 60), // +1h
    createdAt: new Date(),
  };

  const validParent = {
    id: PARENT_ID,
    schoolId: SCHOOL_ID,
    userId: null,
    firstName: 'Padre',
    lastName: 'De Prueba',
    dni: null,
    phone: null,
    email: GOOGLE_EMAIL,
    linkStatus: 'pending',
    isActive: true,
  };

  beforeEach(async () => {
    mockVerifyIdToken.mockReset();
    mockVerifyIdToken.mockResolvedValue({ getPayload: () => validPayload });
    mockCallOrder.length = 0;

    const txMock = {
      user: { create: jest.fn(), updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      userRole: { upsert: jest.fn() },
      parent: { updateMany: jest.fn(), findUnique: jest.fn() },
      parentStudent: { findMany: jest.fn().mockResolvedValue([]) },
      userStudent: { createMany: jest.fn() },
      schoolInvitation: { updateMany: jest.fn(), findUnique: jest.fn() },
    };

    prisma = {
      user: { findUnique: jest.fn() },
      role: { findUnique: jest.fn().mockResolvedValue({ id: PARENT_ROLE_ID }) },
      schoolInvitation: { findUnique: jest.fn() },
      // findFirst por defecto resuelve null (nadie es "padre/usuario de
      // retorno" a menos que un test lo pise explícitamente) — así el resto
      // de los tests, que ejercitan el flujo de invitación de siempre, no
      // cambian.
      parent: { findUnique: jest.fn(), findFirst: jest.fn().mockResolvedValue(null) },
      userRole: { findFirst: jest.fn().mockResolvedValue(null) },
      // Registra su propia invocación en mockCallOrder — así el test de I-2
      // puede verificar que bcrypt.hash ya corrió ANTES de que se abra la
      // transacción, no dentro de ella.
      $transaction: jest.fn(async (cb: any) => {
        mockCallOrder.push('prisma.$transaction');
        return cb(txMock);
      }),
      _tx: txMock, // acceso directo desde los tests para aserciones
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: { sign: jest.fn().mockReturnValue('jwt.fake.token') } },
        {
          provide: ConfigService,
          useValue: { get: jest.fn().mockReturnValue('fake-google-client-id') },
        },
        { provide: SupabaseStorageService, useValue: { getSignedUrls: jest.fn().mockResolvedValue([]) } },
      ],
    }).compile();

    service = moduleRef.get(AuthService);

    // Stubs comunes usados después de la transacción (roles/hijos/tokens).
    jest.spyOn<any, any>(service, '_loadRolesForLogin').mockResolvedValue([
      { roleName: 'parent', schoolId: SCHOOL_ID, schoolName: 'Colegio Test' },
    ]);
    jest.spyOn<any, any>(service, '_loadStudentsForLogin').mockResolvedValue([]);
    jest.spyOn<any, any>(service, 'generateTokens').mockResolvedValue({
      accessToken: 'access', refreshToken: 'refresh',
    });
    jest.spyOn<any, any>(service, 'savePushToken').mockResolvedValue(undefined);
  });

  it('INVITATION_REQUIRED — rechaza si falta invitationToken y no es un padre de retorno', async () => {
    prisma.user.findUnique.mockResolvedValue(null); // googleSub desconocido — no hay a quién "regresar"
    await expect(
      service.loginWithGoogle({ idToken: 'x' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_REQUIRED' });
    // No se CREA ningún User antes de validar la invitación — sí se lo busca
    // (paso 2, para detectar el atajo de retorno), pero nunca se escribe.
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('INVITATION_NOT_FOUND — rechaza si el token no existe', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(null);
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 'no-existe' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_NOT_FOUND' });
  });

  it('INVITATION_EXPIRED — rechaza si venció', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue({
      ...validInvitation,
      expiresAt: new Date(Date.now() - 1000),
    });
    prisma.parent.findUnique.mockResolvedValue(validParent);
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_EXPIRED' });
  });

  it('INVITATION_ALREADY_USED — rechaza si usedAt ya está seteado (Caso A)', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue({ ...validInvitation, usedAt: new Date() });
    prisma.parent.findUnique.mockResolvedValue(validParent);
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_ALREADY_USED' });
  });

  it('INVITATION_INVALID_ROLE — rechaza si roleId no es el de parent', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue({ ...validInvitation, roleId: 999 });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_INVALID_ROLE' });
  });

  // parentId: null ya NO se rechaza — es el caso normal de una invitación
  // GENÉRICA (docente/director). Ver describe('Invitación genérica...') más
  // abajo para la cobertura completa de ese flujo.

  it('INVITATION_INVALID_ROLE — rechaza si el Parent no existe', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
    prisma.parent.findUnique.mockResolvedValue(null);
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_INVALID_ROLE' });
  });

  it('INVITATION_INVALID_ROLE — rechaza si Parent.schoolId ≠ invitation.schoolId', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
    prisma.parent.findUnique.mockResolvedValue({ ...validParent, schoolId: 999n });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_INVALID_ROLE' });
  });

  it('INVITATION_EMAIL_MISMATCH — rechaza si el email no coincide (normalizado)', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue({
      ...validInvitation,
      email: '  OTRO@Gmail.com  ',
    });
    prisma.parent.findUnique.mockResolvedValue(validParent);
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_EMAIL_MISMATCH' });
  });

  it('acepta el email con normalización trim+lowercase idéntica', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue({
      ...validInvitation,
      email: `  ${GOOGLE_EMAIL.toUpperCase()}  `,
    });
    prisma.parent.findUnique.mockResolvedValue(validParent);
    prisma.user.findUnique.mockResolvedValue(null);
    prisma._tx.user.create.mockResolvedValue({
      id: 1n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'De Prueba',
      avatar: null, needsPasswordChange: false,
    });
    prisma._tx.parent.updateMany.mockResolvedValue({ count: 1 });
    prisma._tx.schoolInvitation.updateMany.mockResolvedValue({ count: 1 });

    const result = await service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any);
    expect(result.accessToken).toBe('access');
  });

  it('Caso A — User nuevo: crea User, UserRole y vincula Parent, en la transacción', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
    prisma.parent.findUnique.mockResolvedValue(validParent);
    prisma.user.findUnique.mockResolvedValue(null);
    prisma._tx.user.create.mockResolvedValue({
      id: 5n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'De Prueba',
      avatar: null, needsPasswordChange: false,
    });
    prisma._tx.parent.updateMany.mockResolvedValue({ count: 1 });
    prisma._tx.schoolInvitation.updateMany.mockResolvedValue({ count: 1 });

    await service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any);

    expect(prisma._tx.user.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ googleSub: GOOGLE_SUB }) }),
    );
    expect(prisma._tx.userRole.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: { userId: 5n, roleId: PARENT_ROLE_ID, schoolId: SCHOOL_ID },
      }),
    );
    expect(prisma._tx.parent.updateMany).toHaveBeenCalledWith({
      where: { id: PARENT_ID, userId: null },
      data: { userId: 5n, linkStatus: 'linked' },
    });
    expect(prisma._tx.schoolInvitation.updateMany).toHaveBeenCalledWith({
      where: { id: INVITATION_ID, usedAt: null },
      data: { usedAt: expect.any(Date) },
    });
  });

  it('I-2 — bcrypt.hash del password aleatorio corre ANTES de abrir la transacción, no dentro', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
    prisma.parent.findUnique.mockResolvedValue(validParent);
    prisma.user.findUnique.mockResolvedValue(null);
    prisma._tx.user.create.mockResolvedValue({
      id: 5n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'De Prueba',
      avatar: null, needsPasswordChange: false,
    });
    prisma._tx.parent.updateMany.mockResolvedValue({ count: 1 });
    prisma._tx.schoolInvitation.updateMany.mockResolvedValue({ count: 1 });

    await service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any);

    // bcrypt.hash debe haber corrido, y ANTES de que prisma.$transaction se
    // invoque siquiera — la conexión de BD no debe reservarse mientras la
    // CPU hashea (hallazgo I-2). Antes del fix, ambos ocurrían en el orden
    // inverso: $transaction abría la conexión y bcrypt.hash corría DENTRO.
    expect(mockCallOrder).toEqual(['bcrypt.hash', 'prisma.$transaction']);
  });

  it('Caso A — User existente (mismo googleSub, otro Parent/colegio): reutiliza User, no lo crea, no hashea password', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
    prisma.parent.findUnique.mockResolvedValue(validParent);
    prisma.user.findUnique.mockResolvedValue({
      id: 7n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'Existente',
      avatar: null, needsPasswordChange: false, isActive: true, deletedAt: null,
    });
    prisma._tx.parent.updateMany.mockResolvedValue({ count: 1 });
    prisma._tx.schoolInvitation.updateMany.mockResolvedValue({ count: 1 });

    await service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any);

    expect(prisma._tx.user.create).not.toHaveBeenCalled();
    expect(prisma._tx.parent.updateMany).toHaveBeenCalledWith({
      where: { id: PARENT_ID, userId: null },
      data: { userId: 7n, linkStatus: 'linked' },
    });
    // No hay User que crear → no hace falta generar ni hashear un password
    // aleatorio en absoluto (ni antes ni dentro de la transacción).
    expect(mockCallOrder).not.toContain('bcrypt.hash');
  });

  it('Caso C — Parent ya vinculado a OTRO usuario: rechaza siempre con INVITATION_ALREADY_USED', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
    prisma.parent.findUnique.mockResolvedValue({ ...validParent, userId: 999n, linkStatus: 'linked' });
    prisma.user.findUnique.mockResolvedValue({
      id: 7n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'Otro',
      avatar: null, needsPasswordChange: false, isActive: true, deletedAt: null,
    });

    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_ALREADY_USED' });
    expect(prisma.$transaction).not.toHaveBeenCalled(); // ni siquiera intenta escribir
  });

  it('Caso B — Parent ya vinculado a ESTE MISMO usuario: idempotente, no relanza error ni re-escribe', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
    prisma.parent.findUnique.mockResolvedValue({ ...validParent, userId: 7n, linkStatus: 'linked' });
    prisma.user.findUnique.mockResolvedValue({
      id: 7n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'De Prueba',
      avatar: null, needsPasswordChange: false, isActive: true, deletedAt: null,
    });

    const result = await service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any);

    expect(result.accessToken).toBe('access');
    expect(prisma.$transaction).not.toHaveBeenCalled(); // no toca la BD de nuevo
    expect(mockCallOrder).not.toContain('bcrypt.hash'); // tampoco hashea nada
  });

  describe('Atajo de retorno — padre ya vinculado, SIN invitationToken', () => {
    it('permite el login sin invitationToken cuando el googleSub ya está vinculado a un Parent', async () => {
      prisma.user.findUnique.mockResolvedValue({
        id: 7n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'De Prueba',
        avatar: null, needsPasswordChange: false, isActive: true, deletedAt: null,
      });
      prisma.userRole.findFirst.mockResolvedValue({ id: 1n }); // ya tiene algún rol vinculado

      const result = await service.loginWithGoogle({ idToken: 'x' } as any); // sin invitationToken

      expect(result.accessToken).toBe('access');
      expect(prisma.userRole.findFirst).toHaveBeenCalledWith({
        where: { userId: 7n },
        select: { id: true },
      });
      // No toca nada de invitación ni abre transacción — ya estaba todo vinculado.
      expect(prisma.schoolInvitation.findUnique).not.toHaveBeenCalled();
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('si SÍ mandan invitationToken, NO aplica el atajo aunque ya haya un Parent vinculado (puede ser una vinculación nueva para otro Parent)', async () => {
      // Mismo User ya vinculado a un Parent (findFirst no debería ni
      // invocarse: el atajo se descarta ANTES por haber token), pero llega
      // una invitación nueva — debe procesarse por el flujo normal.
      prisma.user.findUnique.mockResolvedValue({
        id: 7n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'De Prueba',
        avatar: null, needsPasswordChange: false, isActive: true, deletedAt: null,
      });
      prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
      prisma.parent.findUnique.mockResolvedValue(validParent); // Parent B, distinto, sin vincular
      prisma._tx.parent.updateMany.mockResolvedValue({ count: 1 });
      prisma._tx.schoolInvitation.updateMany.mockResolvedValue({ count: 1 });

      const result = await service.loginWithGoogle({
        idToken: 'x',
        invitationToken: 't',
      } as any);

      expect(result.accessToken).toBe('access');
      expect(prisma.userRole.findFirst).not.toHaveBeenCalled(); // el atajo ni se evalúa
      expect(prisma.schoolInvitation.findUnique).toHaveBeenCalled(); // sí procesa la invitación
      expect(prisma._tx.parent.updateMany).toHaveBeenCalledWith({
        where: { id: PARENT_ID, userId: null },
        data: { userId: 7n, linkStatus: 'linked' },
      });
    });

    it('cuenta inactiva/eliminada: rechaza incluso si es un padre ya vinculado (el chequeo corre antes del atajo)', async () => {
      prisma.user.findUnique.mockResolvedValue({
        id: 7n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'De Prueba',
        avatar: null, needsPasswordChange: false, isActive: false, deletedAt: null,
      });
      await expect(
        service.loginWithGoogle({ idToken: 'x' } as any),
      ).rejects.toMatchObject({ message: 'La cuenta está inactiva o ha sido eliminada' });
      expect(prisma.userRole.findFirst).not.toHaveBeenCalled(); // ni llega a chequear el atajo
    });

    it('User existente pero SIN ningún rol vinculado (googleSub sin vínculo): NO aplica el atajo, exige invitationToken', async () => {
      prisma.user.findUnique.mockResolvedValue({
        id: 7n, email: GOOGLE_EMAIL, firstName: 'Otro', lastName: 'Usuario',
        avatar: null, needsPasswordChange: false, isActive: true, deletedAt: null,
      });
      prisma.userRole.findFirst.mockResolvedValue(null); // sin vínculo todavía

      await expect(
        service.loginWithGoogle({ idToken: 'x' } as any), // sin invitationToken
      ).rejects.toMatchObject({ message: 'INVITATION_REQUIRED' });
    });
  });

  it('INVITATION_EMAIL_MISMATCH — rechaza si el email de Google no está verificado (email_verified: false)', async () => {
    mockVerifyIdToken.mockResolvedValue({
      getPayload: () => ({ ...validPayload, email_verified: false }),
    });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_EMAIL_MISMATCH' });
    // Rechazo temprano: ni siquiera llega a buscar la invitación ni a crear nada.
    expect(prisma.schoolInvitation.findUnique).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('INVITATION_EMAIL_MISMATCH — rechaza si email_verified no viene en el payload (undefined)', async () => {
    mockVerifyIdToken.mockResolvedValue({
      getPayload: () => ({ sub: GOOGLE_SUB, email: GOOGLE_EMAIL }),
    });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_EMAIL_MISMATCH' });
  });

  it('Caso A — puente ParentStudent → UserStudent: replica los hijos institucionales del Parent al vincular', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
    prisma.parent.findUnique.mockResolvedValue(validParent);
    prisma.user.findUnique.mockResolvedValue(null);
    prisma._tx.user.create.mockResolvedValue({
      id: 5n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'De Prueba',
      avatar: null, needsPasswordChange: false,
    });
    prisma._tx.parent.updateMany.mockResolvedValue({ count: 1 });
    prisma._tx.parentStudent.findMany.mockResolvedValue([
      { studentId: 20n, relationship: 'padre', isPrimary: true },
      { studentId: 21n, relationship: 'padre', isPrimary: false },
    ]);
    prisma._tx.schoolInvitation.updateMany.mockResolvedValue({ count: 1 });

    await service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any);

    expect(prisma._tx.parentStudent.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { parentId: PARENT_ID } }),
    );
    expect(prisma._tx.userStudent.createMany).toHaveBeenCalledWith({
      data: [
        { userId: 5n, studentId: 20n, relationship: 'padre', isPrimary: true },
        { userId: 5n, studentId: 21n, relationship: 'padre', isPrimary: false },
      ],
      skipDuplicates: true,
    });
  });

  it('Caso A — sin hijos institucionales: no llama a userStudent.createMany', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue(validInvitation);
    prisma.parent.findUnique.mockResolvedValue(validParent);
    prisma.user.findUnique.mockResolvedValue(null);
    prisma._tx.user.create.mockResolvedValue({
      id: 5n, email: GOOGLE_EMAIL, firstName: 'Padre', lastName: 'De Prueba',
      avatar: null, needsPasswordChange: false,
    });
    prisma._tx.parent.updateMany.mockResolvedValue({ count: 1 });
    prisma._tx.schoolInvitation.updateMany.mockResolvedValue({ count: 1 });

    await service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any);

    expect(prisma._tx.userStudent.createMany).not.toHaveBeenCalled();
  });

  it('rechaza ID Token sin sub', async () => {
    mockVerifyIdToken.mockResolvedValue({ getPayload: () => ({ email: GOOGLE_EMAIL }) });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('rechaza ID Token sin email', async () => {
    mockVerifyIdToken.mockResolvedValue({ getPayload: () => ({ sub: GOOGLE_SUB }) });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('rechaza ID Token inválido (verifyIdToken lanza)', async () => {
    mockVerifyIdToken.mockRejectedValue(new Error('invalid token'));
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toThrow(UnauthorizedException);
  });
});

// ============================================================
// Invitación GENÉRICA (docente/director) — sin Parent de por medio.
// El colegio ya debió crear el User institucionalmente (Web Admin) ANTES
// de generar la invitación — a diferencia de Parent, acá no se crea un
// User nuevo a ciegas.
// ============================================================
describe('AuthService.loginWithGoogle — invitación GENÉRICA (docente/director)', () => {
  let service: AuthService;
  let prisma: any;

  const TEACHER_ROLE_ID = 2;
  const SCHOOL_ID = 1n;
  const INVITATION_ID = 200n;
  const GOOGLE_SUB = '99988877766655544433';
  const TEACHER_EMAIL = 'docente@colegio.edu.pe';

  const validPayload = {
    sub: GOOGLE_SUB,
    email: TEACHER_EMAIL,
    email_verified: true,
    given_name: 'Ana',
    family_name: 'García',
    picture: null,
  };

  // parentId: null — es exactamente lo que la distingue de una invitación
  // de Parent, y lo que ahora la enruta a _linkGenericInvitation().
  const genericInvitation = {
    id: INVITATION_ID,
    schoolId: SCHOOL_ID,
    email: TEACHER_EMAIL,
    roleId: TEACHER_ROLE_ID,
    token: 'tok_docente',
    parentId: null,
    invitedBy: 1n,
    usedAt: null,
    expiresAt: new Date(Date.now() + 1000 * 60 * 60),
    createdAt: new Date(),
  };

  // El User que Web Admin ya creó institucionalmente ANTES de la
  // invitación (POST /admin/users) — sin googleSub todavía.
  const preCreatedTeacher = {
    id: 50n, email: TEACHER_EMAIL, firstName: 'Ana', lastName: 'García',
    avatar: null, needsPasswordChange: true, googleSub: null,
    isActive: true, deletedAt: null,
  };

  beforeEach(async () => {
    mockVerifyIdToken.mockReset();
    mockVerifyIdToken.mockResolvedValue({ getPayload: () => validPayload });

    const txMock = {
      user: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      userRole: { upsert: jest.fn() },
      schoolInvitation: { updateMany: jest.fn().mockResolvedValue({ count: 1 }), findUnique: jest.fn() },
    };

    prisma = {
      // Dos usos distintos del mismo método: por googleSub (paso 2, "existing")
      // y por email (dentro de _linkGenericInvitation, "targetUser"). Se
      // distingue por la forma del `where` en cada llamada.
      user: {
        findUnique: jest.fn(({ where }: any) => {
          if ('googleSub' in where) return Promise.resolve(null); // nadie con este googleSub todavía
          if ('email' in where) return Promise.resolve(preCreatedTeacher);
          return Promise.resolve(null);
        }),
      },
      schoolInvitation: { findUnique: jest.fn().mockResolvedValue(genericInvitation) },
      parent: { findFirst: jest.fn().mockResolvedValue(null) },
      userRole: { findFirst: jest.fn().mockResolvedValue(null) },
      $transaction: jest.fn(async (cb: any) => cb(txMock)),
      _tx: txMock,
    };

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: JwtService, useValue: { sign: jest.fn().mockReturnValue('jwt.fake.token') } },
        { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue('fake-google-client-id') } },
        { provide: SupabaseStorageService, useValue: { getSignedUrls: jest.fn().mockResolvedValue([]) } },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
    jest.spyOn<any, any>(service, '_loadRolesForLogin').mockResolvedValue([
      { roleName: 'teacher', schoolId: SCHOOL_ID, schoolName: 'Colegio Test' },
    ]);
    jest.spyOn<any, any>(service, '_loadStudentsForLogin').mockResolvedValue([]);
    jest.spyOn<any, any>(service, 'generateTokens').mockResolvedValue({ accessToken: 'access', refreshToken: 'refresh' });
    jest.spyOn<any, any>(service, 'savePushToken').mockResolvedValue(undefined);
  });

  it('vincula al User pre-creado por el admin: setea googleSub, agrega UserRole, consume la invitación', async () => {
    const result = await service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any);

    expect(result.accessToken).toBe('access');
    expect(prisma._tx.user.updateMany).toHaveBeenCalledWith({
      where: { id: 50n, googleSub: null },
      data: { googleSub: GOOGLE_SUB, isActive: true },
    });
    expect(prisma._tx.userRole.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: { userId: 50n, roleId: TEACHER_ROLE_ID, schoolId: SCHOOL_ID },
      }),
    );
    expect(prisma._tx.schoolInvitation.updateMany).toHaveBeenCalledWith({
      where: { id: INVITATION_ID, usedAt: null },
      data: { usedAt: expect.any(Date) },
    });
    // Sin hijos: es docente, no padre.
    expect(result.user.children).toEqual([]);
  });

  it('INVITATION_EMAIL_MISMATCH — el email de Google debe coincidir con el de la invitación', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue({ ...genericInvitation, email: 'otro@x.com' });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_EMAIL_MISMATCH' });
  });

  it('INVITATION_EXPIRED — rechaza si venció', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue({
      ...genericInvitation, expiresAt: new Date(Date.now() - 1000),
    });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_EXPIRED' });
  });

  it('rechaza si no existe un User pre-creado para ese email (alta a medias)', async () => {
    prisma.user.findUnique.mockImplementation(({ where }: any) => {
      if ('googleSub' in where) return Promise.resolve(null);
      return Promise.resolve(null); // nadie con ese email tampoco
    });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toThrow(NotFoundException);
  });

  it('Caso C-equivalente — el User pre-creado ya está vinculado a OTRA cuenta de Google: rechaza siempre', async () => {
    prisma.user.findUnique.mockImplementation(({ where }: any) => {
      if ('googleSub' in where) return Promise.resolve(null);
      return Promise.resolve({ ...preCreatedTeacher, googleSub: 'otro-sub-distinto' });
    });
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_ALREADY_USED' });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('Caso B-equivalente — invitación ya usada, pero por ESTE MISMO usuario: idempotente, no relanza error', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue({ ...genericInvitation, usedAt: new Date() });
    // Esta vez SÍ hay "existing" (encontrado por googleSub) — ya se vinculó antes.
    prisma.user.findUnique.mockImplementation(({ where }: any) => {
      if ('googleSub' in where) {
        return Promise.resolve({ ...preCreatedTeacher, googleSub: GOOGLE_SUB });
      }
      return Promise.resolve(preCreatedTeacher);
    });
    prisma.userRole.findFirst.mockResolvedValue({ id: 1n }); // ya tiene el UserRole

    const result = await service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any);

    expect(result.accessToken).toBe('access');
    expect(prisma.$transaction).not.toHaveBeenCalled(); // no reescribe nada
  });

  it('invitación ya usada y NO por este usuario: rechaza con INVITATION_ALREADY_USED', async () => {
    prisma.schoolInvitation.findUnique.mockResolvedValue({ ...genericInvitation, usedAt: new Date() });
    // Sin "existing" (googleSub nuevo, no vinculado antes) — no puede ser idempotente.
    await expect(
      service.loginWithGoogle({ idToken: 'x', invitationToken: 't' } as any),
    ).rejects.toMatchObject({ message: 'INVITATION_ALREADY_USED' });
  });
});
