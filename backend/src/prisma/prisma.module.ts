// ============================================================
// prisma.module.ts — Módulo que expone PrismaService
// ============================================================
// Un módulo en NestJS es un contenedor que agrupa:
//   - providers: servicios disponibles dentro del módulo
//   - exports: servicios que otros módulos pueden importar
//
// Al marcar PrismaModule como @Global(), cualquier módulo
// que importe AppModule puede usar PrismaService sin tener
// que importar PrismaModule explícitamente. Conveniente
// porque Prisma se usa en casi todos los módulos.
// ============================================================

import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

// @Global() hace que este módulo sea accesible en toda la app
// sin necesidad de importarlo en cada módulo que lo necesite
@Global()
@Module({
  providers: [PrismaService], // PrismaService vive aquí
  exports: [PrismaService],   // y puede ser usado por otros módulos
})
export class PrismaModule {}
