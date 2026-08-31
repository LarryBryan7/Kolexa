// ============================================================
// Tests unitarios — POST /auth/push-token
// ============================================================
// El token FCM solo se guardaba en login/register/google-login. Si
// cambiaba mientras la sesión seguía activa (reinstalar la app, rotación
// normal de Firebase), no había forma de resincronizarlo — el push
// quedaba muerto en silencio hasta el siguiente login. Este endpoint
// permite resincronizarlo en caliente, sin loguearse de nuevo.
// ============================================================

import { AuthController } from '../../src/modules/auth/auth.controller';

const fakeUser: any = { sub: '15', email: 'x@x.com', roles: ['teacher'], schoolId: 1n };

function makeController(savePushToken = jest.fn().mockResolvedValue(undefined)) {
  const service: any = { savePushToken };
  return { controller: new AuthController(service), service };
}

describe('AuthController.syncPushToken — POST /auth/push-token', () => {
  it('guarda el token y devuelve ok:true', async () => {
    const { controller, service } = makeController();
    const result = await controller.syncPushToken(fakeUser, 'nuevo-token-fcm');
    expect(service.savePushToken).toHaveBeenCalledWith(15n, 'nuevo-token-fcm');
    expect(result).toEqual({ ok: true });
  });

  it('sin firebaseToken no llama al service y devuelve ok:false', async () => {
    const { controller, service } = makeController();
    const result = await controller.syncPushToken(fakeUser, undefined);
    expect(service.savePushToken).not.toHaveBeenCalled();
    expect(result).toEqual({ ok: false });
  });

  it('con firebaseToken vacío tampoco llama al service', async () => {
    const { controller, service } = makeController();
    const result = await controller.syncPushToken(fakeUser, '');
    expect(service.savePushToken).not.toHaveBeenCalled();
    expect(result).toEqual({ ok: false });
  });
});
