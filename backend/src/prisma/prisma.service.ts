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
    // Pasamos configuración a PrismaClient. Los niveles info/warn/error van
    // a stdout — son diagnóstico legítimo de Prisma (ej. avisos de
    // conexión), no instrumentación de depuración. El listener de 'query'
    // que existía aquí (console.log de CADA query SQL ejecutada, sin
    // condicional de entorno) era instrumentación temporal de una
    // investigación de latencia puntual — corría también en producción,
    // sin límite, para siempre. Se eliminó (hallazgo IM-5).
    super({
      log: [
        { emit: 'stdout', level: 'info' },
        { emit: 'stdout', level: 'warn' },
        { emit: 'stdout', level: 'error' },
      ],
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
