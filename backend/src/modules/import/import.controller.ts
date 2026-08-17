// ============================================================
// import.controller.ts — Controlador de importación masiva (Etapa 2)
// ============================================================
// Rutas (prefijo global /api/v1), acceso solo school_admin:
//   POST /api/v1/admin/import/classrooms/preview
//   POST /api/v1/admin/import/classrooms/confirm
//   POST /api/v1/admin/import/courses/preview
//   POST /api/v1/admin/import/courses/confirm
//   POST /api/v1/admin/import/students/preview
//   POST /api/v1/admin/import/students/confirm
//   POST /api/v1/admin/import/teachers/preview
//   POST /api/v1/admin/import/teachers/confirm
//
// Modo seguro: /preview procesa en memoria (sin escribir); /confirm escribe
// solo las filas 'creada'. El schoolId se obtiene del JWT (nunca del body).
// ============================================================

import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ImportService } from './import.service';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser, UserPayload } from '../../common/decorators/current-user.decorator';
import { ImportClassroomsDto } from './dto/import-classrooms.dto';
import { ImportCoursesDto } from './dto/import-courses.dto';
import { ImportStudentsDto } from './dto/import-students.dto';
import { ImportTeachersDto } from './dto/import-teachers.dto';

@Roles('school_admin')
@Controller('admin/import')
export class ImportController {
  constructor(private readonly importService: ImportService) {}

  // ── AULAS ────────────────────────────────────────────────
  @Post('classrooms/preview')
  @HttpCode(HttpStatus.OK)
  previewClassrooms(@CurrentUser() user: UserPayload, @Body() dto: ImportClassroomsDto) {
    return this.importService.previewClassrooms(BigInt(user.schoolId!), dto.csv);
  }

  @Post('classrooms/confirm')
  @HttpCode(HttpStatus.OK)
  confirmClassrooms(@CurrentUser() user: UserPayload, @Body() dto: ImportClassroomsDto) {
    return this.importService.confirmClassrooms(
      BigInt(user.schoolId!),
      dto.csv,
      BigInt(user.sub),
    );
  }

  // ── CURSOS ───────────────────────────────────────────────
  @Post('courses/preview')
  @HttpCode(HttpStatus.OK)
  previewCourses(@CurrentUser() user: UserPayload, @Body() dto: ImportCoursesDto) {
    return this.importService.previewCourses(BigInt(user.schoolId!), dto.csv);
  }

  @Post('courses/confirm')
  @HttpCode(HttpStatus.OK)
  confirmCourses(@CurrentUser() user: UserPayload, @Body() dto: ImportCoursesDto) {
    return this.importService.confirmCourses(BigInt(user.schoolId!), dto.csv);
  }

  // ── DOCENTES ─────────────────────────────────────────────
  @Post('teachers/preview')
  @HttpCode(HttpStatus.OK)
  previewTeachers(@CurrentUser() user: UserPayload, @Body() dto: ImportTeachersDto) {
    return this.importService.previewTeachers(BigInt(user.schoolId!), dto.csv);
  }

  @Post('teachers/confirm')
  @HttpCode(HttpStatus.OK)
  confirmTeachers(@CurrentUser() user: UserPayload, @Body() dto: ImportTeachersDto) {
    return this.importService.confirmTeachers(
      BigInt(user.schoolId!),
      dto.csv,
      BigInt(user.sub),
    );
  }

  // ── ALUMNOS ──────────────────────────────────────────────
  @Post('students/preview')
  @HttpCode(HttpStatus.OK)
  previewStudents(@CurrentUser() user: UserPayload, @Body() dto: ImportStudentsDto) {
    return this.importService.previewStudents(BigInt(user.schoolId!), dto.csv);
  }

  @Post('students/confirm')
  @HttpCode(HttpStatus.OK)
  confirmStudents(@CurrentUser() user: UserPayload, @Body() dto: ImportStudentsDto) {
    return this.importService.confirmStudents(
      BigInt(user.schoolId!),
      dto.csv,
      BigInt(user.sub),
    );
  }
}
