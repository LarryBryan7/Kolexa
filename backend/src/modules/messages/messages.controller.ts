// ============================================================
// messages.controller.ts — Mensajes directos
// ============================================================
// Rutas:
//   POST /messages                  → enviar mensaje
//   GET  /messages/inbox            → bandeja de entrada
//   GET  /messages/sent             → bandeja de enviados
//   GET  /messages/:id/thread       → hilo de conversación
//   PATCH /messages/:id/read        → marcar como leído
// ============================================================

import {
  Controller, Get, Post, Patch, Body, Param, Query, ParseIntPipe,
} from '@nestjs/common';
import { IsString, IsInt, IsOptional, MaxLength, MinLength } from 'class-validator';
import { MessagesService } from './messages.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

class SendMessageDto {
  @IsInt() recipientId: number;
  @IsString() @MinLength(2) @MaxLength(200) subject: string;
  @IsString() @MaxLength(5000) body: string;
  @IsOptional() @IsInt() studentId?: number;
  @IsOptional() @IsInt() parentMessageId?: number;
}

@Controller('messages')
export class MessagesController {
  constructor(private readonly service: MessagesService) {}

  @Post()
  send(@Body() dto: SendMessageDto, @CurrentUser() user: UserPayload) {
    return this.service.send(
      {
        recipientId: BigInt(dto.recipientId),
        subject: dto.subject,
        body: dto.body,
        studentId: dto.studentId,
        parentMessageId: dto.parentMessageId ? BigInt(dto.parentMessageId) : undefined,
      },
      user.sub,
      user.schoolId,
    );
  }

  @Get('inbox')
  getInbox(
    @CurrentUser() user: UserPayload,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.service.getInbox(
      user.sub,
      limit ? parseInt(limit, 10) : 20,
      offset ? parseInt(offset, 10) : 0,
    );
  }

  @Get('sent')
  getSent(@CurrentUser() user: UserPayload) {
    return this.service.getSent(user.sub);
  }

  @Get('unread-count')
  getUnreadCount(@CurrentUser() user: UserPayload) {
    return this.service.getUnreadCount(user.sub);
  }

  @Get(':id/thread')
  getThread(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.getThread(BigInt(id), user.sub);
  }

  @Patch(':id/read')
  markAsRead(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.markAsRead(BigInt(id), user.sub);
  }
}
