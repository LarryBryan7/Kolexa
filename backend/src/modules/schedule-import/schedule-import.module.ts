// ============================================================
// schedule-import.module.ts — Importar horario de aula desde foto
// ============================================================
// GeminiScheduleService se exporta para poder mockearlo en tests y para
// reutilizar la lectura de imagen desde otros módulos (ej. el horario del
// docente en la app móvil) sin duplicar la integración con la IA.
// ============================================================

import { Module } from '@nestjs/common';
import { ScheduleImportController } from './schedule-import.controller';
import { ScheduleImportService } from './schedule-import.service';
import { ClassroomImportService } from './classroom-import.service';
import { GeminiScheduleService } from './gemini-schedule.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [ScheduleImportController],
  providers: [ScheduleImportService, ClassroomImportService, GeminiScheduleService],
  exports: [ScheduleImportService, ClassroomImportService, GeminiScheduleService],
})
export class ScheduleImportModule {}
