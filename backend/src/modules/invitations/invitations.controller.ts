import { Controller, Post, Get, Param, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { InvitationsService } from './invitations.service';
import { CreateInvitationDto } from './dto/create-invitation.dto';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';

// Rutas (prefijo global /api/v1):
//   POST /api/v1/invitations              — crea invitación (requiere JWT)
//   GET  /api/v1/invitations/validate/:token — valida token (público)
@Controller('invitations')
export class InvitationsController {
  constructor(private readonly service: InvitationsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@CurrentUser() user: UserPayload, @Body() dto: CreateInvitationDto) {
    return this.service.create(
      { schoolId: BigInt(dto.schoolId), email: dto.email, roleId: dto.roleId },
      BigInt(user.sub),
    );
  }

  @Public()
  @Get('validate/:token')
  validate(@Param('token') token: string) {
    return this.service.validate(token);
  }
}
