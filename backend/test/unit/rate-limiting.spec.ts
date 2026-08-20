// ============================================================
// Regresión IM-4 (Ronda 4) — rate limiting real (ThrottlerModule)
// ============================================================
// No usa mocks del mecanismo de throttling: levanta una app NestJS real
// (supertest) con el MISMO ThrottlerModule/ThrottlerGuard que
// app.module.ts registra en producción — solo con un controller de
// prueba en vez de los controllers reales, para no depender de Prisma/
// Google/Firebase y mantener el test rápido y aislado. El límite
// estricto (3/min) es deliberadamente bajo SOLO en este controller de
// prueba para no tener que disparar 6 requests reales contra /auth/login
// (5/min) — el mecanismo que se prueba es idéntico al de producción.
// ============================================================

import { Test } from '@nestjs/testing';
import { INestApplication, Controller, Get } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerModule, ThrottlerGuard, Throttle } from '@nestjs/throttler';
import * as request from 'supertest';

@Controller('test-throttle')
class TestThrottleController {
  @Throttle({ default: { limit: 3, ttl: 60_000 } })
  @Get('strict')
  strict() {
    return { ok: true };
  }

  // Sin @Throttle() propio — usa el default global generoso (300/min en
  // producción; aquí replicado igual para probar que no molesta el uso normal).
  @Get('normal')
  normal() {
    return { ok: true };
  }
}

describe('Rate limiting (IM-4) — ThrottlerModule real vía HTTP (supertest)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: 300 }])],
      controllers: [TestThrottleController],
      providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
    }).compile();

    app = moduleRef.createNestApplication();
    // listen() explícito en un puerto efímero (no solo init()): sin esto,
    // supertest abre/cierra un servidor HTTP ad-hoc en CADA request()
    // porque app.getHttpServer() todavía no está escuchando — bajo
    // ráfagas rápidas (10 requests seguidos) ese churn de sockets
    // efímeros producía un "socket hang up" intermitente. Escuchar una
    // sola vez, en un puerto real, elimina la causa.
    await app.listen(0);
  });

  afterAll(async () => {
    await app.close();
  });

  it('debajo del límite (3/min) → las primeras 3 peticiones responden 200', async () => {
    for (let i = 0; i < 3; i++) {
      await request(app.getHttpServer()).get('/test-throttle/strict').expect(200);
    }
  });

  it('exceder el límite → la petición siguiente responde 429', async () => {
    await request(app.getHttpServer()).get('/test-throttle/strict').expect(429);
  });

  it('un endpoint SIN @Throttle() propio (default global 300/min) no se bloquea con uso normal', async () => {
    for (let i = 0; i < 10; i++) {
      await request(app.getHttpServer()).get('/test-throttle/normal').expect(200);
    }
  });
});
