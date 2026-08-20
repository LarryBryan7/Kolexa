// ============================================================
// Regresión IM-1 + IM-2 (auditoría Ronda 3) — revocación de sesión
// ============================================================
// IM-1: logout() nunca tocaba userToken pese a que el comentario de
// generateTokens() decía "para poder invalidarlo en logout" — un refresh
// token seguía siendo válido hasta 7 días después de "cerrar sesión".
// IM-2: refresh() no validaba isActive/deletedAt — un usuario desactivado
// (o su token robado) podía seguir obteniendo access tokens nuevos.
// ============================================================

import { Test } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { AuthService } from '../../src/modules/auth/auth.service';
import { PrismaService } from '../../src/prisma/prisma.service';
import { assertLocalTestDatabase } from '../helpers/db-guard';

assertLocalTestDatabase();

describe('Revocación de sesión — logout()/refresh() (Postgres real)', () => {
  let prisma: PrismaService;
  let authService: AuthService;
  let jwtService: JwtService;
  let userId: bigint;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        PrismaService,
        {
          provide: JwtService,
          useValue: new JwtService({ secret: 'test-secret-session-revocation' }),
        },
        {
          provide: ConfigService,
          useValue: {
            get: (key: string) => {
              if (key === 'JWT_SECRET' || key === 'JWT_REFRESH_SECRET') return 'test-secret-session-revocation';
              return undefined;
            },
          },
        },
      ],
    }).compile();

    prisma = moduleRef.get(PrismaService);
    authService = moduleRef.get(AuthService);
    jwtService = moduleRef.get(JwtService);
    await prisma.$connect();

    const user = await prisma.user.create({
      data: {
        email: `session-revocation-${Date.now()}@idor-test.kolexa`,
        passwordHash: 'x', firstName: 'Test', lastName: 'User', isActive: true,
      },
    });
    userId = user.id;
  });

  afterAll(async () => {
    await prisma.userToken.deleteMany({ where: { userId } });
    await prisma.user.deleteMany({ where: { id: userId } });
    await prisma.$disconnect();
  });

  // deviceTag: discriminador arbitrario. jwtService.sign() incluye `iat`
  // en resolución de SEGUNDOS — dos tokens firmados con el mismo payload
  // dentro del mismo segundo (habitual en un test) producirían el MISMO
  // string. deviceTag garantiza tokens distintos entre "dispositivos".
  function makeRefreshToken(deviceTag = 'default') {
    return jwtService.sign({ sub: userId.toString(), email: 'x@x.com', roles: ['parent'], deviceTag });
  }

  async function storeRefreshToken(token: string) {
    await prisma.userToken.create({
      data: { userId, tokenType: 'refresh', token, expiresAt: new Date(Date.now() + 7 * 86400_000) },
    });
  }

  it('usuario activo → refresh → ✅', async () => {
    const token = makeRefreshToken();
    await storeRefreshToken(token);

    const result = await authService.refresh(token);
    expect(result.accessToken).toBeDefined();
  });

  it('logout(refreshToken específico) invalida ESE token — refresh posterior con el mismo token falla', async () => {
    const token = makeRefreshToken();
    await storeRefreshToken(token);

    // Confirma que funcionaba antes del logout (no es un token inválido de por sí)
    await expect(authService.refresh(token)).resolves.toBeDefined();

    await authService.logout(userId, undefined, token);

    await expect(authService.refresh(token)).rejects.toMatchObject({ status: 401 });
  });

  it('logout(refreshToken específico) NO invalida otras sesiones del mismo usuario (otros dispositivos)', async () => {
    const tokenDeviceA = makeRefreshToken('device-a');
    const tokenDeviceB = makeRefreshToken('device-b');
    await storeRefreshToken(tokenDeviceA);
    await storeRefreshToken(tokenDeviceB);

    await authService.logout(userId, undefined, tokenDeviceA);

    await expect(authService.refresh(tokenDeviceA)).rejects.toMatchObject({ status: 401 });
    // El dispositivo B sigue con sesión válida — logout no destruyó otras sesiones.
    await expect(authService.refresh(tokenDeviceB)).resolves.toBeDefined();

    await prisma.userToken.deleteMany({ where: { userId, token: tokenDeviceB } });
  });

  it('logout() SIN refreshToken (cliente que no lo envía) revoca todos los refresh tokens del usuario — más seguro que no revocar nada', async () => {
    const tokenX = makeRefreshToken('device-x');
    const tokenY = makeRefreshToken('device-y');
    await storeRefreshToken(tokenX);
    await storeRefreshToken(tokenY);

    await authService.logout(userId, undefined, undefined);

    await expect(authService.refresh(tokenX)).rejects.toMatchObject({ status: 401 });
    await expect(authService.refresh(tokenY)).rejects.toMatchObject({ status: 401 });
  });

  it('usuario desactivado → refresh → ❌ (aunque el refresh token en sí siga sin expirar/revocar)', async () => {
    const token = makeRefreshToken();
    await storeRefreshToken(token);

    await prisma.user.update({ where: { id: userId }, data: { isActive: false } });

    await expect(authService.refresh(token)).rejects.toMatchObject({ status: 401 });

    // No romper el resto del flujo normal: reactivar y confirmar que
    // vuelve a funcionar (el fix es un chequeo de estado, no una
    // revocación permanente del token).
    await prisma.user.update({ where: { id: userId }, data: { isActive: true } });
    await expect(authService.refresh(token)).resolves.toBeDefined();

    await prisma.userToken.deleteMany({ where: { userId, token } });
  });

  it('usuario eliminado (deletedAt) → refresh → ❌', async () => {
    const token = makeRefreshToken();
    await storeRefreshToken(token);

    await prisma.user.update({ where: { id: userId }, data: { deletedAt: new Date() } });

    await expect(authService.refresh(token)).rejects.toMatchObject({ status: 401 });

    await prisma.user.update({ where: { id: userId }, data: { deletedAt: null } });
    await prisma.userToken.deleteMany({ where: { userId, token } });
  });

  it('no rompe el flujo normal: refresh con un token nunca guardado (nunca hizo login) sigue devolviendo 401, no 500', async () => {
    const foreignToken = jwtService.sign({ sub: userId.toString(), email: 'x@x.com', roles: [] });
    // Deliberadamente NO se guarda en userToken.
    await expect(authService.refresh(foreignToken)).rejects.toMatchObject({ status: 401 });
  });
});
