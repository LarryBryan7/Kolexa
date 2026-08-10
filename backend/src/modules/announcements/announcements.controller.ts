// ============================================================
// announcements.controller.ts — Controlador de Comunicados
// ============================================================
// Rutas:
//   POST  /announcements                  → crear comunicado
//   GET   /announcements/feed             → feed del usuario actual
//   GET   /announcements/:id              → detalle de un comunicado
//   PATCH /announcements/:id/read         → marcar como leído
//   PATCH /announcements/read-all         → marcar todos como leídos
//   DELETE /announcements/:id             → eliminar
// ============================================================

import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  ParseIntPipe,
} from '@nestjs/common';
import { IsString, IsInt, IsPositive, IsOptional, IsBoolean, MaxLength, MinLength } from 'class-validator';
import { AnnouncementsService } from './announcements.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

// DTO inline para no crear un archivo extra para casos simples
class CreateAnnouncementDto {
  @IsString() @MinLength(3) @MaxLength(200) title: string;
  @IsString() @MaxLength(5000) content: string;
  @IsString() scopeType: string;
  @IsInt() @IsPositive() scopeId: number;
  @IsOptional() @IsBoolean() isPinned?: boolean;
}

@Controller('announcements')
export class AnnouncementsController {
  constructor(private readonly service: AnnouncementsService) {}

  @Post()
  create(@Body() dto: CreateAnnouncementDto, @CurrentUser() user: UserPayload) {
    return this.service.create({ ...dto, schoolId: user.schoolId ?? BigInt(0) }, user.sub);
  }

  // GET /announcements/feed?limit=20&offset=0
  @Get('feed')
  getFeed(
    @CurrentUser() user: UserPayload,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    // schoolId viene del JWT (el usuario está asociado a una escuela)
    return this.service.getFeed(
      user.sub,
      user.schoolId ?? 0,
      limit ? parseInt(limit, 10) : 20,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  // PATCH /announcements/read-all — marcar todos como leídos
  // IMPORTANTE: esta ruta debe ir ANTES de /:id para que NestJS
  // no intente parsear "read-all" como un ID numérico
  @Patch('read-all')
  markAllAsRead(@CurrentUser() user: UserPayload) {
    return this.service.markAllAsRead(user.sub);
  }

  @Get(':id')
  getOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.getById(BigInt(id));
  }

  // PATCH /announcements/:id/read — marcar este comunicado como leído
  @Patch(':id/read')
  markAsRead(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.markAsRead(BigInt(id), user.sub);
  }

  @Delete(':id')
  remove(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.delete(BigInt(id), user.sub);
  }
}
