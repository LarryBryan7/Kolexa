// ============================================================
// prisma.service.ts — Servicio de conexión a la base de datos
// ============================================================
// PrismaService es el puente entre NestJS y PostgreSQL.
// Extiende PrismaClient (el cliente generado por Prisma) y
// añade la lógica de ciclo de vida de NestJS:
//   - onModuleInit → conecta a la BD cuando arranca el servidor
//   - beforeApplicationShutdown → desconecta limpiamente al apagar
//
// Para usarlo en cualquier módulo:
//   constructor(private prisma: PrismaService) {}
//   const users = await this.prisma.user.findMany();
// ============================================================

import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  // Logger de NestJS para mostrar mensajes en consola con contexto
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    // Pasamos configuración a PrismaClient
    super({
      log: [
        // En desarrollo mostramos todas las queries SQL para depurar
        { emit: 'event', level: 'query' },
        { emit: 'stdout', level: 'info' },
        { emit: 'stdout', level: 'warn' },
        { emit: 'stdout', level: 'error' },
      ],
    });

    // ── Instrumentación temporal de latencia Prisma/PostgreSQL ──
    // Mide el tiempo de ejecución SQL reportado por Prisma (evento 'query').
    // La duración que reporta Prisma es el tiempo de ejecución en el servidor
    // (no incluye adquisición de conexión ni latencia de red del pooler).
    // Para separar red/adquisición de conexión usamos la prueba [PRISMA-PING].
    (this as any).$on('query', (e: any) => {
      console.log(`[PRISMA-QUERY] ${e.duration} ms | ${e.query.slice(0, 120)}`);
    });
  }

  // onModuleInit se ejecuta automáticamente cuando NestJS
  // termina de inicializar este módulo. Es el momento ideal
  // para conectar a la base de datos.
  async onModuleInit() {
    try {
      // $connect() establece la conexión con PostgreSQL
      await this.$connect();
      this.logger.log('✅ Conectado a PostgreSQL via Prisma');

      // ── Prueba temporal de latencia Prisma/PostgreSQL ──
      // Ejecuta N consultas triviales SELECT 1 consecutivas para medir la
      // latencia total por operación (adquisición de conexión del pooler +
      // latencia de red + ejecución SQL + release). Comparar con el
      // [PRISMA-QUERY] (solo ejecución SQL) para separar red/pooler.
      const PING_COUNT = 10;
      console.log(`[PRISMA-PING] start count=${PING_COUNT}`);
      for (let i = 1; i <= PING_COUNT; i++) {
        const pingStart = Date.now();
        await this.$queryRawUnsafe('SELECT 1');
        const pingEnd = Date.now();
        console.log(`[PRISMA-PING] #${i} total=${pingEnd - pingStart} ms`);
      }
      console.log('[PRISMA-PING] end');
    } catch (error) {
      this.logger.error('❌ Error al conectar a PostgreSQL', error);
      // Si no se puede conectar, el servidor no debería arrancar
      throw error;
    }
  }

  // beforeApplicationShutdown se ejecuta cuando el proceso
  // de Node.js recibe una señal de apagado (SIGINT, SIGTERM).
  // Es importante cerrar la conexión limpiamente para evitar
  // conexiones huérfanas en PostgreSQL.
  async beforeApplicationShutdown() {
    await this.$disconnect();
    this.logger.log('🔌 Desconectado de PostgreSQL');
  }
}
