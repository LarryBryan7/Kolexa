// ============================================================
// schedule-import.controller.ts — Importar horario desde foto
// ============================================================
// Rutas (prefijo global /api/v1), solo school_admin:
//   POST /api/v1/admin/schedule-import/analyze   (multipart: image)
//   POST /api/v1/admin/schedule-import/confirm   (JSON, ya revisado)
//
// /analyze NO escribe en la base de datos: solo devuelve la propuesta para
// que el administrador la revise. /confirm es el único que persiste.
// El schoolId sale SIEMPRE del JWT, nunca del body.
// ============================================================

import {
  Controller,
  Get,
  Post,
  Body,
  HttpCode,
  HttpStatus,
  UploadedFile,
  UseInterceptors,
  BadRequestException,
  Query,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { Throttle } from '@nestjs/throttler';
import { ScheduleImportService } from './schedule-import.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';
import { ConfirmScheduleImportDto } from './dto/confirm-schedule-import.dto';
import { ConfirmClassroomImportDto } from './dto/confirm-classroom-import.dto';
import { ClassroomImportService } from './classroom-import.service';

// Gemini acepta hasta 20MB por request (imagen + prompt). Se limita bien por
// debajo: una foto de horario no necesita más, y un tope bajo reduce el
// costo de un abuso del endpoint.
const SCHEDULE_IMAGE_MAX_BYTES = 8 * 1024 * 1024; // 8MB

// Formatos que Gemini acepta como inline data. Se validan explícitamente en
// vez de aceptar cualquier image/*: un SVG, por ejemplo, es un vector de
// ataque (XML con scripts) y además el modelo no lo procesa.
const ALLOWED_MIME = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'];

@Roles('school_admin')
@Controller('admin/schedule-import')
export class ScheduleImportController {
  constructor(
    private readonly service: ScheduleImportService,
    private readonly classroomImport: ClassroomImportService,
  ) {}

  // Rate limit propio y estricto: cada llamada consume cuota de Gemini, así
  // que es mucho más caro que un endpoint normal (el límite global es 300/min).
  @Post('analyze')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @UseInterceptors(
    FileInterceptor('image', {
      storage: memoryStorage(),
      limits: { fileSize: SCHEDULE_IMAGE_MAX_BYTES, files: 1 },
      fileFilter: (_req, file, cb) => {
        if (!ALLOWED_MIME.includes(file.mimetype)) {
          return cb(
            new BadRequestException('Formato no admitido. Usa una imagen JPG, PNG o WEBP.'),
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  analyze(
    @CurrentUser() user: UserPayload,
    @UploadedFile() image: Express.Multer.File,
    // Opcional: si el admin ya eligió el aula en la UI, esa manda sobre la
    // que se detecte en la foto.
    @Query('classroomId') classroomId?: string,
  ) {
    if (!image) {
      throw new BadRequestException('Falta la imagen del horario.');
    }
    return this.service.analyze(
      BigInt(user.schoolId!),
      image.buffer.toString('base64'),
      image.mimetype,
      classroomId ? BigInt(classroomId) : undefined,
    );
  }

  @Post('confirm')
  @HttpCode(HttpStatus.OK)
  confirm(@CurrentUser() user: UserPayload, @Body() dto: ConfirmScheduleImportDto) {
    return this.service.confirm(
      BigInt(user.schoolId!),
      BigInt(dto.classroomId),
      dto.blocks,
    );
  }

  // ── Importar aulas y cursos desde Google Classroom ──────────
  // Mismo contrato: analyze propone (sin escribir), confirm persiste.

  @Get('classroom/analyze')
  classroomAnalyze(@CurrentUser() user: UserPayload) {
    return this.classroomImport.analyze(BigInt(user.schoolId!));
  }

  @Post('classroom/confirm')
  @HttpCode(HttpStatus.OK)
  classroomConfirm(
    @CurrentUser() user: UserPayload,
    @Body() dto: ConfirmClassroomImportDto,
  ) {
    return this.classroomImport.confirm(BigInt(user.schoolId!), dto.groups);
  }
}
