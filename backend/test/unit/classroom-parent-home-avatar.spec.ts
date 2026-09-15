// ============================================================
// Tests unitarios — avatar recién firmado en GET /classroom/parent/home
// ============================================================
// El avatar del hijo solo se firmaba en el login (URL firmada, vence en
// 1h) y nunca se volvía a firmar durante la sesión — si la app quedaba
// abierta/en background más de una hora, la foto desaparecía (la petición
// a la URL vencida fallaba y el cliente caía al círculo con iniciales).
// `getParentHome` ahora firma el avatar de nuevo en cada llamada, así el
// refresh que ya se dispara al volver del background lo renueva solo.
// ============================================================

import { ClassroomService } from '../../src/modules/classroom/classroom.service';

function makeService(opts: { studentAvatar: string | null; signedUrls?: string[] }) {
  const prisma: any = {
    $queryRaw: jest.fn().mockResolvedValue([]), // sessionRows
    student: {
      findUnique: jest.fn().mockResolvedValue({ avatar: opts.studentAvatar }),
    },
    // null = sin Classroom conectado, para no disparar syncStudent() (que
    // llamaría a la API real de Google) — no es el foco de este archivo.
    googleToken: {
      findUnique: jest.fn().mockResolvedValue(null),
    },
    $transaction: jest.fn(async (arg: any) => {
      if (typeof arg === 'function') {
        const tx = { $queryRaw: jest.fn().mockResolvedValue([]) };
        return arg(tx);
      }
      return Promise.all(arg);
    }),
  };
  const config: any = { get: jest.fn() };
  const storage: any = { getSignedUrls: jest.fn().mockResolvedValue(opts.signedUrls ?? []) };
  const service = new ClassroomService(prisma, config, storage);
  return { service, prisma, storage };
}

describe('ClassroomService.getParentHome — avatar recién firmado', () => {
  it('devuelve un avatarUrl recién firmado cuando el alumno tiene foto', async () => {
    const { service, storage } = makeService({
      studentAvatar: 'avatars/3/foto.jpg',
      signedUrls: ['https://signed.example/foto.jpg'],
    });

    const result = await service.getParentHome(3n);

    expect(result.avatarUrl).toBe('https://signed.example/foto.jpg');
    expect(storage.getSignedUrls).toHaveBeenCalledWith(['avatars/3/foto.jpg'], 3600, 'avatars');
  });

  it('avatarUrl es null si el alumno no tiene foto, y no intenta firmar el avatar', async () => {
    const { service, storage } = makeService({ studentAvatar: null });

    const result = await service.getParentHome(3n);

    expect(result.avatarUrl).toBeNull();
    // getSignedUrls también se usa (sin relación) para las fotos de
    // asistencia del día — se verifica que nunca se lo llamó con el
    // bucket 'avatars', no que nunca se lo llamó en absoluto.
    expect(storage.getSignedUrls).not.toHaveBeenCalledWith(
      expect.anything(),
      expect.anything(),
      'avatars',
    );
  });

  it('sigue devolviendo todaySummary y upcomingStatus junto con el avatar', async () => {
    const { service } = makeService({ studentAvatar: null });

    const result = await service.getParentHome(3n);

    expect(result).toHaveProperty('todaySummary');
    expect(result).toHaveProperty('upcomingStatus');
    expect(result).toHaveProperty('avatarUrl');
  });
});

describe('ClassroomService.getParentHome — dispara syncStudent si hay Classroom conectado', () => {
  it('llama a syncStudent() en paralelo cuando el alumno tiene un google_token', async () => {
    const { service, prisma } = makeService({ studentAvatar: null });
    prisma.googleToken.findUnique.mockResolvedValue({ id: 1n });
    // No sincroniza de verdad (no hay mock de la API de Google) — solo se
    // verifica que getParentHome() lo intenta, que es el fix real: antes
    // nunca llamaba a syncStudent() bajo ninguna circunstancia.
    const syncSpy = jest.spyOn(service, 'syncStudent').mockResolvedValue({
      courses: 0,
      courseworks: 0,
      cacheHit: true,
    });

    await service.getParentHome(3n);

    expect(syncSpy).toHaveBeenCalledWith(3n);
  });

  it('NO llama a syncStudent() si el alumno no tiene Classroom conectado', async () => {
    const { service } = makeService({ studentAvatar: null });
    const syncSpy = jest.spyOn(service, 'syncStudent');

    await service.getParentHome(3n);

    expect(syncSpy).not.toHaveBeenCalled();
  });

  it('un error de syncStudent() no rompe getParentHome (sigue con lo que ya había)', async () => {
    const { service, prisma } = makeService({ studentAvatar: null });
    prisma.googleToken.findUnique.mockResolvedValue({ id: 1n });
    jest.spyOn(service, 'syncStudent').mockRejectedValue(new Error('invalid_grant'));

    await expect(service.getParentHome(3n)).resolves.toHaveProperty('todaySummary');
  });
});
