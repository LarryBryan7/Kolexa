// ============================================================
// attendance.module.ts — Módulo de Asistencia
// ============================================================
// Un módulo en NestJS agrupa todos los componentes relacionados.
// Es como una "caja" que contiene el Controller, Service, y
// cualquier otra dependencia del módulo de asistencia.
//
// NestJS usa módulos para:
//   - Organizar el código en unidades lógicas
//   - Controlar qué se exporta (disponible para otros módulos)
//   - Establecer las dependencias entre módulos
//
// No necesitamos importar PrismaModule aquí porque lo declaramos
// como @Global() en prisma.module.ts — está disponible en toda la app.
// ============================================================

import { Module } from '@nestjs/common';
import { AttendanceController } from './attendance.controller';
import { AttendanceService } from './attendance.service';

@Module({
  // controllers: quién maneja las peticiones HTTP
  controllers: [AttendanceController],

  // providers: servicios disponibles dentro de este módulo
  // NestJS los instancia y los inyecta donde se necesiten
  providers: [AttendanceService],

  // exports: qué puede usar OTRO módulo si importa AttendanceModule
  // (por ahora no exportamos nada — no hay otro módulo que lo necesite)
  exports: [AttendanceService],
})
export class AttendanceModule {}
