import {
  Controller,
  Get,
  Post,
  Body,
  Request,
  UseGuards,
  UseInterceptors,
  UploadedFiles,
} from '@nestjs/common';
import { FilesInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { TeachersService, ScheduleBlockInput, AttendanceRecordInput } from './teachers.service';
import { SupabaseStorageService } from '../storage/supabase-storage.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('teachers')
export class TeachersController {
  constructor(
    private readonly teachersService: TeachersService,
    private readonly storageService: SupabaseStorageService,
  ) {}

  @Get('me/home')
  getHome(@Request() req: any) {
    return this.teachersService.getHomeData(BigInt(req.user.sub));
  }

  @Get('me/schedule/today')
  getTodaySchedule(@Request() req: any) {
    return this.teachersService.getTodaySchedule(BigInt(req.user.sub));
  }

  @Post('me/attendance')
  saveAttendance(
    @Request() req: any,
    @Body() body: { date: string; records: AttendanceRecordInput[] },
  ) {
    return this.teachersService.saveAttendance(BigInt(req.user.sub), body.date, body.records ?? []);
  }

  @Post('me/attendance/photos')
  @UseInterceptors(FilesInterceptor('photos', 10, { storage: memoryStorage() }))
  async uploadAttendancePhotos(
    @Request() req: any,
    @UploadedFiles() files: Express.Multer.File[],
    @Body() body: { date: string },
  ) {
    // NOTA (no corregido en este cambio): la subida ocurre ANTES de validar
    // que exista una gc_attendance_session para este docente+fecha. Si no
    // existe, saveAttendancePhotos() lanza BadRequestException y el archivo
    // queda huérfano en Storage (ya subido, sin fila que lo referencie).
    // Detectado en auditoría de seguridad — pendiente de corrección aparte.
    const prefix = `${req.user.sub}/${body.date}`;
    const photoUrls = await this.storageService.uploadPhotos(files ?? [], prefix);
    return this.teachersService.saveAttendancePhotos(BigInt(req.user.sub), body.date, photoUrls);
  }

  @Post('me/schedule')
  saveSchedule(
    @Request() req: any,
    @Body() body: { blocks: ScheduleBlockInput[] },
  ) {
    return this.teachersService.saveSchedule(BigInt(req.user.sub), body.blocks ?? []);
  }
}
