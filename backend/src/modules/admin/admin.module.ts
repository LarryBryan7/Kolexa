// ============================================================
// admin.module.ts — Módulo de la Web Admin
// ============================================================
// Agrupa el controlador y el servicio de administración.
// El RolesGuard se registra como guard global (APP_GUARD) pero
// solo actúa en endpoints marcados con @Roles(); el resto de la
// app no se ve afectado.
// ============================================================

import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { RolesGuard } from '../../common/guards/roles.guard';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [AdminController],
  providers: [
    AdminService,
    // RolesGuard global: verifica @Roles() en los endpoints que lo usen
    {
      provide: APP_GUARD,
      useClass: RolesGuard,
    },
  ],
})
export class AdminModule {}
