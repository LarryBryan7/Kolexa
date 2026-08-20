// ============================================================
// Tests unitarios — contrato de códigos estructurados (H-01)
// ============================================================
// Antes de este fix, tanto un JWT de KOLEXA vencido como un token OAuth de
// Google Classroom vencido devolvían un 401 cuyo `message` contenía la
// palabra "token" — Flutter clasificaba por substring y confundía ambos
// casos (ver auth_interceptor.dart / api_client.dart). Estos tests
// verifican el contrato del lado del backend: dos códigos estructurados
// distintos, nunca confundibles por su forma.
// ============================================================

import { Reflector } from '@nestjs/core';
import { UnauthorizedException } from '@nestjs/common';
import { JwtAuthGuard } from '../../src/common/guards/jwt-auth.guard';
import { ClassroomController } from '../../src/modules/classroom/classroom.controller';
import { HttpExceptionFilter } from '../../src/common/filters/http-exception.filter';

function captureThrow(fn: () => any): any {
  try {
    fn();
  } catch (e) {
    return e;
  }
  throw new Error('Se esperaba que la función lanzara, pero no lanzó.');
}

async function captureRejection(promise: Promise<any>): Promise<any> {
  try {
    await promise;
  } catch (e) {
    return e;
  }
  throw new Error('Se esperaba que la promesa rechazara, pero se resolvió.');
}

function bodyOf(exception: UnauthorizedException): any {
  return exception.getResponse();
}

describe('JwtAuthGuard.handleRequest — code SESSION_TOKEN_EXPIRED', () => {
  const guard = new JwtAuthGuard(new Reflector());

  it('un JWT inválido/expirado devuelve code = SESSION_TOKEN_EXPIRED', () => {
    const exception = captureThrow(() => guard.handleRequest(new Error('jwt expired'), null));
    expect(bodyOf(exception)).toMatchObject({ statusCode: 401, code: 'SESSION_TOKEN_EXPIRED' });
  });

  it('sin usuario (passport no lo resolvió) también devuelve SESSION_TOKEN_EXPIRED', () => {
    const exception = captureThrow(() => guard.handleRequest(null, null));
    expect(bodyOf(exception)).toMatchObject({ code: 'SESSION_TOKEN_EXPIRED' });
  });

  it('un usuario válido pasa sin lanzar', () => {
    const user = { sub: 1n, email: 'x@x.com', roles: [] };
    expect(guard.handleRequest(null, user)).toBe(user);
  });
});

describe('ClassroomController — code GOOGLE_TOKEN_EXPIRED (los 3 endpoints)', () => {
  // fakeUser: BL-6 (auditoría Ronda 3) agregó assertStudentOwnedByParent()
  // antes de sync/getOverview — se mockea resuelta para no interferir con
  // estos tests, que verifican específicamente el mapeo de errores de
  // Google, no el ownership (eso lo cubre classroom-ownership.spec.ts).
  const fakeUser: any = { sub: 1n, email: 'x@x.com', roles: ['parent'], schoolId: 1n };

  function makeController(rejectWith: any) {
    const mockService: any = {
      syncTeacher: jest.fn().mockRejectedValue(rejectWith),
      syncStudent: jest.fn().mockRejectedValue(rejectWith),
      getOverview: jest.fn().mockRejectedValue(rejectWith),
      assertStudentOwnedByParent: jest.fn().mockResolvedValue(undefined),
    };
    return new ClassroomController(mockService);
  }

  const invalidGrantError = { response: { data: { error: 'invalid_grant' } } };
  const invalidTokenError = { response: { data: { error: 'invalid_token: revoked' } } };

  it('teacher/sync — invalid_grant de Google se traduce a GOOGLE_TOKEN_EXPIRED', async () => {
    const controller = makeController(invalidGrantError);
    const exception = await captureRejection(controller.syncTeacher({ user: { sub: '1' } } as any));
    expect(bodyOf(exception)).toMatchObject({ statusCode: 401, code: 'GOOGLE_TOKEN_EXPIRED' });
  });

  it('student/:id/sync — invalid_token de Google se traduce a GOOGLE_TOKEN_EXPIRED', async () => {
    const controller = makeController(invalidTokenError);
    const exception = await captureRejection(controller.sync(5n, fakeUser));
    expect(bodyOf(exception)).toMatchObject({ statusCode: 401, code: 'GOOGLE_TOKEN_EXPIRED' });
  });

  it('student/:id/overview — invalid_grant de Google se traduce a GOOGLE_TOKEN_EXPIRED', async () => {
    const controller = makeController(invalidGrantError);
    const exception = await captureRejection(controller.getOverview(5n, fakeUser));
    expect(bodyOf(exception)).toMatchObject({ statusCode: 401, code: 'GOOGLE_TOKEN_EXPIRED' });
  });

  it('los 3 endpoints usan exactamente el mismo code', async () => {
    const e1 = await captureRejection(
      makeController(invalidGrantError).syncTeacher({ user: { sub: '1' } } as any),
    );
    const e2 = await captureRejection(makeController(invalidGrantError).sync(5n, fakeUser));
    const e3 = await captureRejection(makeController(invalidGrantError).getOverview(5n, fakeUser));

    expect([bodyOf(e1).code, bodyOf(e2).code, bodyOf(e3).code]).toEqual([
      'GOOGLE_TOKEN_EXPIRED', 'GOOGLE_TOKEN_EXPIRED', 'GOOGLE_TOKEN_EXPIRED',
    ]);
  });

  it('un error de Google NO relacionado con el token se propaga tal cual (no se convierte en GOOGLE_TOKEN_EXPIRED)', async () => {
    const otherError = { response: { data: { error: 'rate_limit_exceeded' } } };
    const controller = makeController(otherError);
    const rejected = await captureRejection(controller.syncTeacher({ user: { sub: '1' } } as any));
    expect(rejected).toBe(otherError);
  });

  it('un error inesperado sin forma reconocible tampoco se convierte en GOOGLE_TOKEN_EXPIRED', async () => {
    const genericError = new Error('conexión rechazada');
    const controller = makeController(genericError);
    const rejected = await captureRejection(controller.syncTeacher({ user: { sub: '1' } } as any));
    expect(rejected).toBe(genericError);
  });
});

describe('HttpExceptionFilter — propaga `code` cuando la excepción lo trae', () => {
  function runFilter(exception: unknown) {
    const filter = new HttpExceptionFilter();
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const host: any = {
      switchToHttp: () => ({
        getResponse: () => ({ status }),
        getRequest: () => ({ url: '/api/v1/classroom/teacher/sync' }),
      }),
    };
    filter.catch(exception, host);
    return { status, json };
  }

  it('incluye code en el JSON cuando la excepción lo trae (SESSION_TOKEN_EXPIRED)', () => {
    const guard = new JwtAuthGuard(new Reflector());
    const exception = captureThrow(() => guard.handleRequest(new Error('expired'), null));

    const { status, json } = runFilter(exception);
    expect(status).toHaveBeenCalledWith(401);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'SESSION_TOKEN_EXPIRED', statusCode: 401 }),
    );
  });

  it('incluye code en el JSON cuando la excepción lo trae (GOOGLE_TOKEN_EXPIRED)', async () => {
    const controller = new ClassroomController({
      syncTeacher: jest.fn().mockRejectedValue({ response: { data: { error: 'invalid_grant' } } }),
    } as any);
    const exception = await captureRejection(controller.syncTeacher({ user: { sub: '1' } } as any));

    const { json } = runFilter(exception);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({ code: 'GOOGLE_TOKEN_EXPIRED' }),
    );
  });

  it('NO agrega `code` cuando la excepción original no lo trae (sin contratos rotos para el resto de la API)', () => {
    const { json } = runFilter(new UnauthorizedException('Credenciales incorrectas'));
    const body = json.mock.calls[0][0];
    expect(body.code).toBeUndefined();
    expect(body.message).toBe('Credenciales incorrectas');
  });
});
