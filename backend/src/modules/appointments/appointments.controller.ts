import { Controller, Get, Post, Patch, Body, Param, Query, ParseIntPipe } from '@nestjs/common';
import { IsString, IsInt, IsPositive, IsOptional, IsNumber } from 'class-validator';
import { AppointmentsService } from './appointments.service';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';

class CreateSlotDto {
  @IsString() startTime: string;
  @IsString() endTime: string;
  @IsOptional() @IsString() location?: string;
  @IsOptional() @IsInt() maxBookings?: number;
}

class BookAppointmentDto {
  @IsInt() @IsPositive() slotId: number;
  @IsInt() @IsPositive() studentId: number;
  @IsString() reason: string;
}

class UpdateStatusDto {
  @IsString() status: 'scheduled' | 'completed' | 'cancelled' | 'no_show';
  @IsOptional() @IsString() notes?: string;
}

@Controller('appointments')
export class AppointmentsController {
  constructor(private readonly service: AppointmentsService) {}

  @Post('slots')
  createSlot(@Body() dto: CreateSlotDto, @CurrentUser() user: UserPayload) {
    return this.service.createSlot({ ...dto, schoolId: user.schoolId ?? BigInt(0) }, user.sub);
  }

  @Get('slots')
  getAvailableSlots(@CurrentUser() user: UserPayload) {
    return this.service.getAvailableSlots(user.schoolId ?? BigInt(0));
  }

  @Get('slots/:teacherId')
  getTeacherSlots(
    @Param('teacherId', ParseIntPipe) teacherId: number,
    @Query('from') from?: string,
  ) {
    return this.service.getTeacherSlots(BigInt(teacherId), from);
  }

  @Post()
  book(@Body() dto: BookAppointmentDto, @CurrentUser() user: UserPayload) {
    return this.service.bookAppointment(dto, user.sub);
  }

  @Get('my')
  getMyAppointments(
    @CurrentUser() user: UserPayload,
    @Query('role') role: 'parent' | 'teacher' = 'parent',
  ) {
    return this.service.getMyAppointments(user, role);
  }

  @Patch(':id/status')
  updateStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateStatusDto,
    @CurrentUser() user: UserPayload,
  ) {
    return this.service.updateStatus(id, dto.status, user.sub, dto.notes);
  }
}
