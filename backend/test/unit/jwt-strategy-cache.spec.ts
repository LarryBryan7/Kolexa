// ============================================================
// Tests unitarios — caché corta de "usuario activo" en JwtStrategy
// ============================================================
// Cada request autenticado (toda la app, no solo mensajería) hacía un
// findFirst a la base para confirmar que el usuario sigue activo. En
// producción esa consulta cuesta ~350-400ms contra el pooler de Supabase.
// Se agregó una caché en memoria con TTL de 30s: la navegación normal
// (varias pantallas en pocos segundos) paga la consulta una sola vez.
// Estos tests verifican el contrato: cache hit no repite la consulta,
// cache expirado sí, y un usuario inactivo nunca queda cacheado.
// ============================================================

import { UnauthorizedException } from '@nestjs/common';
import { JwtStrategy } from '../../src/modules/auth/strategies/jwt.strategy';

function makeStrategy(userFindFirst: jest.Mock, userRoleFindFirst = jest.fn()) {
  const configService = { get: jest.fn().mockReturnValue('test-secret') } as any;
  const prisma = {
    user: { findFirst: userFindFirst },
    userRole: { findFirst: userRoleFindFirst },
  } as any;
  return new JwtStrategy(configService, prisma);
}

describe('JwtStrategy — caché de usuario activo', () => {
  afterEach(() => {
    jest.useRealTimers();
  });

  it('primera llamada consulta la base y arma el payload con schoolId del JWT', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: 15n, email: 'bryan@kolexa.pe' });
    const strategy = makeStrategy(findFirst);

    const result = await strategy.validate({ sub: '15', roles: ['teacher'], schoolId: '1' });

    expect(result).toEqual({ sub: 15n, email: 'bryan@kolexa.pe', roles: ['teacher'], schoolId: 1n });
    expect(findFirst).toHaveBeenCalledTimes(1);
  });

  it('segunda llamada dentro del TTL NO vuelve a consultar la base', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: 15n, email: 'bryan@kolexa.pe' });
    const strategy = makeStrategy(findFirst);

    await strategy.validate({ sub: '15', roles: ['teacher'], schoolId: '1' });
    await strategy.validate({ sub: '15', roles: ['teacher'], schoolId: '1' });
    await strategy.validate({ sub: '15', roles: ['teacher'], schoolId: '1' });

    expect(findFirst).toHaveBeenCalledTimes(1);
  });

  it('pasado el TTL (30s), vuelve a consultar la base', async () => {
    jest.useFakeTimers();
    const findFirst = jest.fn().mockResolvedValue({ id: 15n, email: 'bryan@kolexa.pe' });
    const strategy = makeStrategy(findFirst);

    await strategy.validate({ sub: '15', roles: ['teacher'], schoolId: '1' });
    jest.advanceTimersByTime(30_001);
    await strategy.validate({ sub: '15', roles: ['teacher'], schoolId: '1' });

    expect(findFirst).toHaveBeenCalledTimes(2);
  });

  it('usuarios distintos tienen entradas de caché independientes', async () => {
    const findFirst = jest.fn().mockImplementation(({ where }: any) =>
      Promise.resolve({ id: where.id, email: `user${where.id}@kolexa.pe` }),
    );
    const strategy = makeStrategy(findFirst);

    await strategy.validate({ sub: '15', roles: ['teacher'], schoolId: '1' });
    await strategy.validate({ sub: '21', roles: ['parent'], schoolId: '1' });
    await strategy.validate({ sub: '15', roles: ['teacher'], schoolId: '1' }); // cache hit
    await strategy.validate({ sub: '21', roles: ['parent'], schoolId: '1' }); // cache hit

    expect(findFirst).toHaveBeenCalledTimes(2);
  });

  it('usuario no encontrado/inactivo rechaza y no queda cacheado (el siguiente intento vuelve a consultar)', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    const strategy = makeStrategy(findFirst);

    await expect(strategy.validate({ sub: '99', roles: [], schoolId: '1' })).rejects.toThrow(
      UnauthorizedException,
    );
    await expect(strategy.validate({ sub: '99', roles: [], schoolId: '1' })).rejects.toThrow(
      UnauthorizedException,
    );

    // Sin caché "envenenada": cada intento fallido vuelve a preguntarle a la base
    // (para que, si el usuario se reactiva, el siguiente request ya lo vea).
    expect(findFirst).toHaveBeenCalledTimes(2);
  });

  it('token sin schoolId en el payload (formato viejo) hace fallback a userRole, incluso en un cache hit', async () => {
    const findFirst = jest.fn().mockResolvedValue({ id: 15n, email: 'bryan@kolexa.pe' });
    const userRoleFindFirst = jest.fn().mockResolvedValue({ schoolId: 7n });
    const strategy = makeStrategy(findFirst, userRoleFindFirst);

    const r1 = await strategy.validate({ sub: '15', roles: ['teacher'] }); // sin schoolId
    const r2 = await strategy.validate({ sub: '15', roles: ['teacher'] }); // cache hit, sigue sin schoolId

    expect(r1.schoolId).toBe(7n);
    expect(r2.schoolId).toBe(7n);
    expect(findFirst).toHaveBeenCalledTimes(1); // el cache hit sí ahorra esta consulta
    expect(userRoleFindFirst).toHaveBeenCalledTimes(2); // el fallback de schoolId no se cachea
  });
});
