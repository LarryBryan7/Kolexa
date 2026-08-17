// ============================================================
// import.module.ts — Módulo de importación masiva (Etapa 2)
// ============================================================
// Agrupa el controlador y el servicio de importación.
// El RolesGuard (registrado como APP_GUARD en AdminModule) protege
// los endpoints marcados con @Roles('school_admin').
// ============================================================

import { Module } from '@nestjs/common';
import { ImportController } from './import.controller';
import { ImportService } from './import.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [ImportController],
  providers: [ImportService],
})
export class ImportModule {}
