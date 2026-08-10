import { Controller, Get, Post, Delete, Body, Param, ParseIntPipe } from '@nestjs/common';
import { IsString, IsInt, IsPositive, IsOptional } from 'class-validator';
import { PickupService } from './pickup.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

class AddAuthorizedDto {
  @IsInt() @IsPositive() studentId: number;
  @IsString() fullName: string;
  @IsString() relationship: string;
  @IsOptional() @IsString() documentId?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() photoUrl?: string;
}

class LogPickupDto {
  @IsInt() @IsPositive() studentId: number;
  @IsOptional() @IsInt() pickedUpById?: number;
  @IsString() pickedUpByName: string;
  @IsOptional() @IsString() notes?: string;
  @IsOptional() @IsString() photoUrl?: string;
}

@Controller('pickup')
export class PickupController {
  constructor(private readonly service: PickupService) {}

  @Post('authorized')
  addAuthorized(@Body() dto: AddAuthorizedDto, @CurrentUser() user: UserPayload) {
    return this.service.addAuthorizedPerson(dto, user.sub);
  }

  @Get('student/:studentId/authorized')
  getAuthorized(
    @Param('studentId', ParseIntPipe) studentId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.getAuthorizedList(studentId, user.sub);
  }

  @Delete('authorized/:id')
  removeAuthorized(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.removeAuthorizedPerson(id, user.sub);
  }

  @Post('events')
  logEvent(@Body() dto: LogPickupDto, @CurrentUser() user: UserPayload) {
    return this.service.logPickupEvent(dto, user.sub);
  }

  @Get('student/:studentId/history')
  getHistory(
    @Param('studentId', ParseIntPipe) studentId: number,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.getPickupHistory(studentId, user.sub);
  }
}
