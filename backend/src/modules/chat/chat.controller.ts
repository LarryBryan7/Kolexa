// ============================================================
// chat.controller.ts
// ============================================================
// Rutas:
//   GET  /chat/conversations                    → mis conversaciones
//   POST /chat/conversations/private            → iniciar chat privado
//   POST /chat/conversations/group              → crear grupo
//   GET  /chat/conversations/:id/messages       → historial de mensajes
//   POST /chat/conversations/:id/messages       → enviar mensaje
// ============================================================

import {
  Controller, Get, Post, Body, Param, Query, ParseIntPipe,
} from '@nestjs/common';
import { IsInt, IsString, IsArray, MaxLength } from 'class-validator';
import { ChatService } from './chat.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

class StartPrivateChatDto {
  @IsInt() recipientId: number;
}

class CreateGroupDto {
  @IsString() @MaxLength(100) name: string;
  @IsArray() @IsInt({ each: true }) participantIds: number[];
}

class SendChatMessageDto {
  @IsString() @MaxLength(4000) content: string;
}

@Controller('chat')
export class ChatController {
  constructor(private readonly service: ChatService) {}

  @Get('conversations')
  getConversations(@CurrentUser() user: UserPayload) {
    return this.service.getConversations(user.sub);
  }

  @Post('conversations/private')
  startPrivateChat(
    @Body() dto: StartPrivateChatDto,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.getOrCreateConversation(user.sub, BigInt(dto.recipientId));
  }

  @Post('conversations/group')
  createGroup(@Body() dto: CreateGroupDto, @CurrentUser() user: UserPayload) {
    return this.service.createGroupConversation(
      dto.name,
      dto.participantIds.map(BigInt),
      user.sub,
    );
  }

  @Get('conversations/:id/messages')
  getMessages(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: UserPayload,
    @Query('limit') limit?: string,
    @Query('before') before?: string,
  ) {
    return this.service.getMessages(
      BigInt(id),
      user.sub,
      limit ? parseInt(limit, 10) : 50,
      before ? BigInt(before) : undefined,
    );
  }

  @Post('conversations/:id/messages')
  sendMessage(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: SendChatMessageDto,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.sendMessage(BigInt(id), dto.content, user.sub);
  }
}
